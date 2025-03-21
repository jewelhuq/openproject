#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

describe Member, type: :model do
  let(:user) { create(:user) }
  let(:role) { create(:role) }
  let(:project) { create(:project) }
  let(:member) { create(:member, user: user, roles: [role]) }
  let(:new_member) { build(:member, user: user, roles: [role], project: project) }

  describe '#project' do
    context 'with a project' do
      it 'is valid' do
        expect(new_member)
          .to be_valid
      end
    end

    context 'without a project (global)' do
      let(:project) { nil }

      it 'is valid' do
        expect(new_member)
          .to be_valid
      end
    end

    context 'without a project (global) but with a global membership already existing' do
      let(:project) { nil }
      let!(:existing_member) { create(:member, user: user, roles: [role], project: project) }

      it 'is invalid' do
        expect(new_member)
          .to be_invalid
      end
    end
  end

  describe '#deletable_role?' do
    it 'returns true if not inherited from a group' do
      expect(member.deletable_role?(role)).to eq(true)
    end

    it 'returns false if role is inherited' do
      member
      group = create(:group, members: [user])
      create(:member, project: project, principal: group, roles: [role])
      ::Groups::AddUsersService
        .new(group, current_user: User.system, contract_class: EmptyContract)
        .call(ids: [user.id])

      expect(user.reload.memberships.map { _1.deletable_role?(role) }).to match_array([true, false])
    end
  end
end
