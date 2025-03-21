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

describe 'version show graph', type: :feature, js: true do
  let(:user) { create :admin }
  let(:project) { create(:project) }
  let(:version) { create(:version, project: project) }

  let!(:wp) do
    create :work_package,
           project: project,
           version: version
  end

  before do
    login_as(user)
    visit version_path(version)
  end

  it 'shows a status graph' do
    expect(page).to have_selector('.work-packages-embedded-view--container', wait: 20)
    expect(page).to have_selector('.chartjs-size-monitor', visible: :all, wait: 20)
  end
end
