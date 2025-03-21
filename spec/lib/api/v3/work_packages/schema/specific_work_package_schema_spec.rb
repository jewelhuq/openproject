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

describe ::API::V3::WorkPackages::Schema::SpecificWorkPackageSchema do
  let(:project) { build_stubbed(:project) }
  let(:type) { build_stubbed(:type) }
  let(:work_package) do
    build_stubbed(:work_package,
                  project: project,
                  type: type)
  end
  let(:current_user) do
    double('current user').tap do |u|
      allow(u)
        .to receive(:allowed_to?)
        .and_return(true)
    end
  end

  before do
    login_as(current_user)
  end

  subject { described_class.new(work_package: work_package) }

  it 'has the project set' do
    expect(subject.project).to eql(project)
  end

  it 'has the type set' do
    expect(subject.type).to eql(type)
  end

  it 'has an id' do
    expect(subject.id).to eql(work_package.id)
  end

  describe '#milestone?' do
    it "shows the work_package's value" do
      allow(work_package)
        .to receive(:milestone?)
        .and_return(true)

      is_expected.to be_milestone

      allow(work_package)
        .to receive(:milestone?)
        .and_return(false)

      is_expected.to_not be_milestone
    end
  end

  describe '#readonly?' do
    it "modifies the writable attributes" do
      allow(work_package)
        .to receive(:readonly_status?)
        .and_return(true)

      is_expected.to be_readonly
      expect(subject.writable?(:status)).to be_truthy
      expect(subject.writable?(:subject)).to be_falsey

      allow(work_package)
        .to receive(:readonly_status?)
        .and_return(false)

      # As the writability is memoized we need to have a new schema
      new_schema = described_class.new(work_package: work_package)
      expect(new_schema).to_not be_readonly
      expect(new_schema.writable?(:status)).to be_truthy
      expect(new_schema.writable?(:subject)).to be_truthy
    end
  end

  describe '#available_custom_fields' do
    it 'delegates to work_package' do
      expect(work_package)
        .to receive(:available_custom_fields)

      subject.available_custom_fields
    end
  end

  describe '#assignable_types' do
    let(:result) do
      result = double
      allow(result).to receive(:includes).and_return(result)
      result
    end

    it 'calls through to the project' do
      expect(project).to receive(:types).and_return(result)
      expect(subject.assignable_values(:type, current_user)).to eql(result)
    end
  end

  describe '#assignable_versions' do
    let(:result) { double }

    it 'calls through to the work package' do
      expect(work_package).to receive(:assignable_versions).and_return(result)
      expect(subject.assignable_values(:version, current_user)).to eql(result)
    end
  end

  describe '#assignable_priorities' do
    let(:active_priority) { build(:priority, active: true) }
    let(:inactive_priority) { build(:priority, active: false) }

    before do
      active_priority.save!
      inactive_priority.save!
    end

    it 'returns only active priorities' do
      expect(subject.assignable_values(:priority, current_user).size).to be >= 1
      subject.assignable_values(:priority, current_user).each do |priority|
        expect(priority.active).to be_truthy
      end
    end
  end

  describe '#assignable_categories' do
    let(:category) { double('category') }

    before do
      allow(project).to receive(:categories).and_return([category])
    end

    it 'returns all categories of the project' do
      expect(subject.assignable_values(:category, current_user)).to match_array([category])
    end
  end

  describe '#assignable_budgets' do
    subject { described_class.new(work_package: work_package) }

    before do
      allow(project).to receive(:budgets).and_return(double('Budgets'))
    end

    it 'returns project.budgets' do
      expect(subject.assignable_values(:budget, nil)).to eql(project.budgets)
    end
  end

  describe '#writable?' do
    context 'percentage done' do
      it 'is not writable when inferred by status' do
        allow(Setting).to receive(:work_package_done_ratio).and_return('status')
        expect(subject.writable?(:percentage_done)).to be false
      end

      it 'is not writable when disabled' do
        allow(Setting).to receive(:work_package_done_ratio).and_return('disabled')
        expect(subject.writable?(:percentage_done)).to be false
      end

      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:percentage_done)).to be false
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:percentage_done)).to be true
      end
    end

    context 'estimated time' do
      it 'is writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:estimated_time)).to be true
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:estimated_time)).to be true
      end
    end

    context 'derived estimated time' do
      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:derived_estimated_time)).to be false
      end

      it 'is not writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:derived_estimated_time)).to be false
      end
    end

    context 'start date' do
      context 'work package is parent' do
        before do
          allow(work_package)
            .to receive(:leaf?)
            .and_return(false)
        end

        context 'scheduled automatically' do
          it 'is not writable' do
            expect(subject.writable?(:start_date)).to be false
          end
        end

        context 'scheduled manually' do
          before do
            work_package.schedule_manually = true
          end

          it 'is writable' do
            expect(subject.writable?(:start_date)).to be true
          end
        end
      end

      context 'work package is a leaf' do
        it 'is writable' do
          allow(work_package).to receive(:leaf?).and_return(true)
          expect(subject.writable?(:start_date)).to be true
        end
      end
    end

    context 'due date' do
      context 'work package is parent' do
        before do
          allow(work_package)
            .to receive(:leaf?)
            .and_return(false)
        end

        context 'scheduled automatically' do
          it 'is not writable' do
            expect(subject.writable?(:due_date)).to be false
          end
        end

        context 'scheduled manually' do
          before do
            work_package.schedule_manually = true
          end

          it 'is writable' do
            expect(subject.writable?(:due_date)).to be true
          end
        end
      end

      context 'work package is a leaf' do
        it 'is writable' do
          allow(work_package).to receive(:leaf?).and_return(true)
          expect(subject.writable?(:due_date)).to be true
        end
      end
    end

    context 'date' do
      # As a date only exists on milestones, which can have no children
      # we do not need to check for differences caused by scheduling modes.
      before do
        allow(work_package.type).to receive(:is_milestone?).and_return(true)
      end

      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:date)).to be false
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:date)).to be true
      end
    end

    context 'priority' do
      it 'is writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:priority)).to be true
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:priority)).to be true
      end
    end
  end

  describe '#assignable_custom_field_values' do
    let(:list_cf) { create(:list_wp_custom_field) }
    let(:version_cf) { build_stubbed(:version_wp_custom_field) }

    it "is a list custom fields' possible values" do
      expect(subject.assignable_custom_field_values(list_cf))
        .to match_array list_cf.possible_values
    end

    it "is a version custom fields' project values" do
      result = double('versions')

      allow(work_package)
        .to receive(:assignable_versions)
        .and_return(result)

      expect(subject.assignable_custom_field_values(version_cf)).to eql result
    end
  end
end
