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

# rubocop:disable RSpec:MultipleMemoizedHelpers
describe 'Projects copy',
         type: :feature,
         js: true do
  describe 'with a full copy example' do
    let!(:project) do
      create(:project,
             parent: parent_project,
             types: active_types,
             members: { user => role },
             custom_field_values: { project_custom_field.id => 'some text cf' }).tap do |p|
        p.work_package_custom_fields << wp_custom_field
        p.types.first.custom_fields << wp_custom_field

        # Enable wiki
        p.enabled_module_names += ['wiki']
      end
    end

    let!(:parent_project) do
      project = create(:project)

      create(:member,
             project: project,
             user: user,
             roles: [role])
      project
    end
    let!(:project_custom_field) do
      create(:text_project_custom_field, is_required: true)
    end
    let!(:wp_custom_field) do
      create(:text_wp_custom_field)
    end
    let!(:inactive_wp_custom_field) do
      create(:text_wp_custom_field)
    end
    let(:active_types) do
      [create(:type), create(:type)]
    end
    let!(:inactive_type) do
      create(:type)
    end
    let(:user) { create(:user) }
    let(:role) do
      create(:role,
             permissions: permissions)
    end
    let(:permissions) { %i(copy_projects edit_project add_subprojects manage_types view_work_packages select_custom_fields) }
    let(:wp_user) do
      user = create(:user)

      create(:member,
             project: project,
             user: user,
             roles: [role])
      user
    end
    let(:category) do
      create(:category, project: project)
    end
    let(:version) do
      create(:version, project: project)
    end
    let!(:work_package) do
      create(:work_package,
             project: project,
             type: project.types.first,
             author: wp_user,
             assigned_to: wp_user,
             responsible: wp_user,
             done_ratio: 20,
             category: category,
             version: version,
             description: 'Some description',
             custom_field_values: { wp_custom_field.id => 'Some wp cf text' })
    end

    let!(:wiki) { project.wiki }
    let!(:wiki_page) do
      create :wiki_page_with_content,
             title: 'Attached',
             wiki: wiki,
             attachments: [build(:attachment, container: nil, filename: 'attachment.pdf')]
    end

    let(:parent_field) { ::FormFields::SelectFormField.new :parent }

    before do
      login_as user

      # Clear all jobs that would later on to having emails send.
      # The jobs are created as part of the object creation.
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it 'copies projects and the associated objects' do
      original_settings_page = Pages::Projects::Settings.new(project)
      original_settings_page.visit!

      find('.toolbar a', text: 'Copy').click

      expect(page).to have_text "Copy project \"#{project.name}\""

      fill_in 'Name', with: 'Copied project', wait: 10

      # Expand advanced settings
      click_on 'Advanced settings'

      # the value of the custom field should be preselected
      editor = ::Components::WysiwygEditor.new "[data-qa-field-name='customField#{project_custom_field.id}']"
      editor.expect_value 'some text cf'

      # Deactivate sending of mails during copying
      click_on 'Copy options'
      uncheck 'Send email notifications during the project copy'

      click_button 'Save'

      expect(page).to have_text 'The job has been queued and will be processed shortly.'

      # ensure all jobs are run especially emails which might be sent later on
      while perform_enqueued_jobs > 0 do end

      copied_project = Project.find_by(name: 'Copied project')

      expect(copied_project)
        .to be_present

      # Will redirect to the new project automatically once the copy process is done
      expect(page).to have_current_path(Regexp.new("#{project_path(copied_project)}/?"))

      copied_settings_page = Pages::Projects::Settings.new(copied_project)
      copied_settings_page.visit!

      # has the parent of the original project
      parent_field.expect_selected parent_project.name

      # copies over the value of the custom field
      # has the parent of the original project
      editor = ::Components::WysiwygEditor.new "[data-qa-field-name='customField#{project_custom_field.id}']"
      editor.expect_value 'some text cf'

      # has wp custom fields of original project active
      copied_settings_page.visit_tab!('custom_fields')

      copied_settings_page.expect_wp_custom_field_active(wp_custom_field)
      copied_settings_page.expect_wp_custom_field_inactive(inactive_wp_custom_field)

      # has types of original project activ
      copied_settings_page.visit_tab!('types')

      active_types.each do |type|
        copied_settings_page.expect_type_active(type)
      end

      copied_settings_page.expect_type_inactive(inactive_type)

      # Expect wiki was copied
      expect(copied_project.wiki.pages.count).to eq(project.wiki.pages.count)
      copied_page = copied_project.wiki.find_page 'Attached'
      expect(copied_page).not_to be_nil
      expect(copied_page.attachments.count).to eq 1
      expect(copied_page.attachments.first.filename).to eq 'attachment.pdf'

      # custom field is copied over where the author is the current user
      # Using the db directly due to performance and clarity
      copied_work_packages = copied_project.work_packages

      expect(copied_work_packages.length)
        .to eql 1

      copied_work_package = copied_work_packages[0]

      expect(copied_work_package.subject)
        .to eql work_package.subject
      expect(copied_work_package.author)
        .to eql user
      expect(copied_work_package.assigned_to)
        .to eql work_package.assigned_to
      expect(copied_work_package.responsible)
        .to eql work_package.responsible
      expect(copied_work_package.status)
        .to eql work_package.status
      expect(copied_work_package.done_ratio)
        .to eql work_package.done_ratio
      expect(copied_work_package.description)
        .to eql work_package.description
      expect(copied_work_package.category)
        .to eql copied_project.categories.find_by(name: category.name)
      expect(copied_work_package.version)
        .to eql copied_project.versions.find_by(name: version.name)
      expect(copied_work_package.custom_value_attributes)
        .to eql(wp_custom_field.id => 'Some wp cf text')

      expect(ActionMailer::Base.deliveries.count)
        .to eql(1)

      expect(ActionMailer::Base.deliveries.last.subject)
        .to eql("Created project Copied project")

      expect(ActionMailer::Base.deliveries.last.to)
        .to match_array([user.mail])
    end
  end

  describe 'copying a set of ordered work packages' do
    let(:user) { create :admin }
    let(:project) { create :project, types: [type] }
    let(:type) { create :type }
    let(:status) { create :status }
    let(:priority) { create :priority }

    let(:default_params) do
      { type: type, status: status, project: project, priority: priority }
    end

    let(:parent1) { create :work_package, default_params.merge(subject: 'Initial phase') }
    let(:child1_1) { create :work_package, default_params.merge(parent: parent1, subject: 'Confirmation phase') }
    let(:child1_2) { create :work_package, default_params.merge(parent: parent1, subject: 'Initiation') }
    let(:parent2) { create :work_package, default_params.merge(subject: 'Execution') }
    let(:child2_1) { create :work_package, default_params.merge(parent: parent2, subject: 'Define goal') }
    let(:child2_2) { create :work_package, default_params.merge(parent: parent2, subject: 'Specify metrics') }
    let(:child2_3) { create :work_package, default_params.merge(parent: parent2, subject: 'Prepare launch') }
    let(:child2_4) { create :work_package, default_params.merge(parent: parent2, subject: 'Launch') }

    let(:order) do
      [parent1, child1_1, child1_2, parent2, child2_1, child2_2, child2_3, child2_4]
    end

    before do
      # create work packages in expected order
      order

      # Clear all jobs that would later on to having emails send.
      # The jobs are created as part of the object creation.
      clear_enqueued_jobs
      clear_performed_jobs

      login_as user
    end

    let(:wp_table) { ::Pages::WorkPackagesTable.new project }

    let(:copied_project) { Project.find_by(name: 'Copied project') }
    let(:copy_wp_table) { ::Pages::WorkPackagesTable.new copied_project }

    it 'copies them in the same order' do
      wp_table.visit!
      wp_table.expect_work_package_listed *order
      wp_table.expect_work_package_order *order

      original_settings_page = Pages::Projects::Settings.new(project)
      original_settings_page.visit!

      find('.toolbar a', text: 'Copy').click

      fill_in 'Name', with: 'Copied project'

      click_button 'Save'

      expect(page).to have_text 'The job has been queued and will be processed shortly.'

      perform_enqueued_jobs

      expect(copied_project)
        .to be_present

      wp_table.visit!
      wp_table.expect_work_package_listed *order
      wp_table.expect_work_package_order *order
    end
  end
end
# rubocop:enable RSpec:MultipleMemoizedHelpers
