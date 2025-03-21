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

describe JournalsController, type: :controller do
  let(:user) { create(:user, member_in_project: project, member_through_role: role) }
  let(:project) { create(:project_with_types) }
  let(:role) { create(:role, permissions: permissions) }
  let(:member) do
    build(:member, project: project,
                              roles: [role],
                              principal: user)
  end
  let(:work_package) do
    build(:work_package, type: project.types.first,
                                    author: user,
                                    project: project,
                                    description: '')
  end
  let(:journal) do
    create(:work_package_journal,
           journable: work_package,
           user: user)
  end
  let(:permissions) { [:view_work_packages] }

  before do
    allow(User).to receive(:current).and_return user
  end

  describe 'GET diff' do
    render_views

    let(:params) { { id: work_package.journals.last.id.to_s, field: :description, format: 'js' } }

    before do
      work_package.update_attribute :description, 'description'

      get :diff,
          xhr: true,
          params: params
    end

    describe 'w/ authorization' do
      it 'should be successful' do
        expect(response).to be_successful
      end

      it 'should present the diff correctly' do
        expect(response.body.strip).to eq("<div class=\"text-diff\">\n  <label class=\"hidden-for-sighted\">Begin of the insertion</label><ins class=\"diffmod\">description</ins><label class=\"hidden-for-sighted\">End of the insertion</label>\n</div>")
      end
    end

    describe 'w/o authorization' do
      let(:permissions) { [] }
      it { expect(response).not_to be_successful }
    end
  end
end
