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
require 'rack/test'

describe "API v3 version's projects resource" do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  let(:current_user) do
    user = create(:user,
                  member_in_project: project,
                  member_through_role: role)

    allow(User).to receive(:current).and_return user

    user
  end
  let(:role) { create(:role, permissions: [:view_work_packages]) }
  let(:role_without_permissions) { create(:role, permissions: []) }
  let(:project) { create(:project, public: false) }
  let(:project2) { create(:project, public: false) }
  let(:project3) { create(:project, public: false) }
  let(:project4) { create(:project, public: false) }
  let(:version) { create(:version, project: project, sharing: 'system') }

  subject(:response) { last_response }

  describe '#get (index)' do
    let(:get_path) { api_v3_paths.projects_by_version version.id }

    context 'logged in user with permissions' do
      before do
        current_user

        # this is to be included
        create(:member, user: current_user,
                                   project: project2,
                                   roles: [role])
        # this is to be included as the user is a member of the project, the
        # lack of permissions is irrelevant.
        create(:member, user: current_user,
                                   project: project3,
                                   roles: [role_without_permissions])
        # project4 should NOT be included
        project4

        get get_path
      end

      it_behaves_like 'API V3 collection response', 3, 3, 'Project'

      it 'includes only the projects which the user can see' do
        id_in_response = JSON.parse(response.body)['_embedded']['elements'].map { |p| p['id'] }

        expect(id_in_response).to match_array [project.id, project2.id, project3.id]
      end
    end

    context 'logged in user without permissions' do
      let(:role) { role_without_permissions }

      before do
        current_user

        get get_path
      end

      it_behaves_like 'not found'
    end
  end
end
