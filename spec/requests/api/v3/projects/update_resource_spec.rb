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

describe 'API v3 Project resource update', type: :request, content_type: :json do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  let(:admin) { create(:admin) }
  let(:project) do
    create(:project, public: false, status: project_status, active: project_active)
  end
  let(:project_active) { true }
  let(:project_status) do
    build(:project_status, project: nil)
  end
  let(:other_project) do
    create(:project, public: false)
  end
  let(:role) { create(:role) }
  let(:custom_field) do
    create(:text_project_custom_field)
  end
  let(:custom_value) do
    CustomValue.create(custom_field: custom_field,
                       value: '1234',
                       customized: project)
  end
  let(:permissions) { [:edit_project] }
  let(:path) { api_v3_paths.project(project.id) }
  let(:body) do
    {
      identifier: 'new_project_identifier',
      name: 'Project name'
    }
  end

  current_user do
    create(:user,
           member_in_project: project,
           member_with_permissions: permissions)
  end

  before do
    patch path, body.to_json
  end

  it 'responds with 200 OK' do
    expect(last_response.status).to eq(200)
  end

  it 'alters the project' do
    project.reload

    expect(project.name)
      .to eql(body[:name])

    expect(project.identifier)
      .to eql(body[:identifier])
  end

  it 'returns the updated project' do
    expect(last_response.body)
      .to be_json_eql('Project'.to_json)
            .at_path('_type')
    expect(last_response.body)
      .to be_json_eql(body[:name].to_json)
            .at_path('name')
  end

  context 'with a custom field' do
    let(:body) do
      {
        "customField#{custom_field.id}": {
          raw: "CF text"
        }
      }
    end

    it 'responds with 200 OK' do
      expect(last_response.status).to eq(200)
    end

    it 'sets the cf value' do
      expect(project.reload.send("custom_field_#{custom_field.id}"))
        .to eql("CF text")
    end
  end

  context 'without permission to patch projects' do
    let(:permissions) { [] }

    it 'responds with 403' do
      expect(last_response.status).to eq(403)
    end

    it 'does not change the project' do
      attributes_before = project.attributes

      expect(project.reload.name)
        .to eql(attributes_before['name'])
    end
  end

  context 'with a nil status' do
    let(:body) do
      {
        statusExplanation: {
          raw: "Some explanation."
        },
        _links: {
          status: {
            href: nil
          }
        }
      }
    end

    it 'alters the status' do
      expect(last_response.body)
        .to be_json_eql(nil.to_json)
              .at_path('_links/status/href')

      status = project.status.reload
      expect(status.code).to be_nil
      expect(status.explanation).to eq 'Some explanation.'

      expect(last_response.body)
        .to be_json_eql(
          {
            format: "markdown",
            html: "<p class=\"op-uc-p\">Some explanation.</p>",
            raw: "Some explanation."
          }.to_json
        )
        .at_path("statusExplanation")
    end
  end

  context 'with a status' do
    let(:body) do
      {
        statusExplanation: {
          raw: "Some explanation."
        },
        _links: {
          status: {
            href: api_v3_paths.project_status('off_track')
          }
        }
      }
    end

    it 'alters the status' do
      expect(last_response.body)
        .to be_json_eql(api_v3_paths.project_status('off_track').to_json)
              .at_path('_links/status/href')

      expect(last_response.body)
        .to be_json_eql(
          {
            format: "markdown",
            html: "<p class=\"op-uc-p\">Some explanation.</p>",
            raw: "Some explanation."
          }.to_json
        )
        .at_path("statusExplanation")
    end

    it 'persists the altered status' do
      project_status.reload

      expect(project_status.code)
        .to eql('off_track')

      expect(project_status.explanation)
        .to eql('Some explanation.')
    end
  end

  context 'with faulty name' do
    let(:body) do
      {
        name: nil
      }
    end

    it 'responds with 422' do
      expect(last_response.status).to eq(422)
    end

    it 'does not change the project' do
      attributes_before = project.attributes

      expect(project.reload.name)
        .to eql(attributes_before['name'])
    end

    it 'denotes the error' do
      expect(last_response.body)
        .to be_json_eql('Error'.to_json)
              .at_path('_type')

      expect(last_response.body)
        .to be_json_eql("Name can't be blank.".to_json)
              .at_path('message')
    end
  end

  context 'with a faulty status' do
    let(:body) do
      {
        _links: {
          status: {
            href: api_v3_paths.project_status("bogus")
          }
        }
      }
    end

    it 'responds with 422' do
      expect(last_response.status).to eq(422)
    end

    it 'does not change the project status' do
      code_before = project_status.code

      expect(project_status.reload.code)
        .to eql(code_before)
    end

    it 'denotes the error' do
      expect(last_response.body)
        .to be_json_eql('Error'.to_json)
              .at_path('_type')

      expect(last_response.body)
        .to be_json_eql("Status is not set to one of the allowed values.".to_json)
              .at_path('message')
    end
  end

  context 'when deactivating (archiving) the project' do
    context 'for an admin' do
      let(:current_user) do
        create(:admin)
      end
      let(:project) do
        create(:project).tap do |p|
          p.children << child_project
        end
      end
      let(:child_project) do
        create(:project)
      end

      let(:body) do
        {
          active: false
        }
      end

      it 'responds with 200 OK' do
        expect(last_response.status)
          .to be(200)
      end

      it 'archives the project' do
        expect(project.reload.active)
          .to be_falsey
      end

      it 'archives the child project' do
        expect(child_project.reload.active)
          .to be_falsey
      end
    end

    context 'for a non admin' do
      let(:body) do
        {
          active: false
        }
      end

      it 'responds with 403' do
        expect(last_response.status)
          .to be(403)
      end

      it 'does not alter the project' do
        expect(project.reload.active)
          .to be_truthy
      end
    end
  end
end
