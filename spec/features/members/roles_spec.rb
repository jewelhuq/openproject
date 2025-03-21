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

describe 'members pagination', type: :feature, js: true do
  shared_let(:admin) { create :admin }
  let(:project) do
    create :project,
           name: 'Project 1',
           identifier: 'project1',
           members: {
             alice => beta,
             bob => alpha
           }
  end

  let(:bob)   { create :user, firstname: 'Bob', lastname: 'Bobbit' }
  let(:alice) { create :user, firstname: 'Alice', lastname: 'Alison' }

  let(:alpha) { create :role, name: 'alpha' }
  let(:beta)  { create :role, name: 'beta' }

  let(:members_page) { Pages::Members.new project.identifier }

  current_user { admin }

  before do
    members_page.visit!
  end

  scenario 'Adding a Role to Alice' do
    members_page.edit_user! 'Alice Alison', add_roles: ['alpha']

    expect(members_page).to have_user('Alice Alison', roles: ['alpha', 'beta'])
  end

  scenario 'Adding a role while taking another role away from Alice' do
    members_page.edit_user! 'Alice Alison', add_roles: ['alpha'], remove_roles: ['beta']

    expect(members_page).to have_user('Alice Alison', roles: 'alpha')
    expect(members_page).not_to have_roles('Alice Alison', ['beta'])
  end

  scenario "Removing Bob's last role results in an error" do
    members_page.edit_user! 'Bob Bobbit', remove_roles: ['alpha']

    expect(page).to have_text 'Roles need to be assigned.'
    expect(members_page).to have_user('Bob Bobbit', roles: ['alpha'])
  end
end
