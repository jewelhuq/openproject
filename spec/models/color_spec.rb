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

describe Color, type: :model do
  describe '- Relations ' do
    describe '#planning_element_types' do
      it 'can read planning_element_types w/ the help of the has_many association' do
        color                 = create(:color)
        planning_element_type = create(:type,
                                       color_id: color.id)

        color.reload

        expect(color.planning_element_types.size).to eq(1)
        expect(color.planning_element_types.first).to eq(planning_element_type)
      end

      it 'nullifies dependent planning_element_types' do
        color                 = create(:color)
        planning_element_type = create(:type,
                                       color_id: color.id)

        color.reload
        color.destroy

        planning_element_type.reload
        expect(planning_element_type.color_id).to be_nil
      end
    end
  end

  describe '- Validations ' do
    let(:attributes) do
      { name: 'Color No. 1',
        hexcode: '#FFFFFF' }
    end

    describe 'name' do
      it 'is invalid w/o a name' do
        attributes[:name] = nil
        color = Color.new(attributes)

        expect(color).not_to be_valid

        expect(color.errors[:name]).to be_present
        expect(color.errors[:name]).to eq(["can't be blank."])
      end

      it 'is invalid w/ a name longer than 255 characters' do
        attributes[:name] = 'A' * 500
        color = Color.new(attributes)

        expect(color).not_to be_valid

        expect(color.errors[:name]).to be_present
        expect(color.errors[:name]).to eq(['is too long (maximum is 255 characters).'])
      end
    end

    describe 'hexcode' do
      it 'is invalid w/o a hexcode' do
        attributes[:hexcode] = nil
        color = Color.new(attributes)

        expect(color).not_to be_valid

        expect(color.errors[:hexcode]).to be_present
        expect(color.errors[:hexcode]).to eq(["can't be blank."])
      end

      it 'is invalid w/ malformed hexcodes' do
        expect(Color.new(attributes.merge(hexcode: '0#FFFFFF'))).not_to be_valid
        expect(Color.new(attributes.merge(hexcode: '#FFFFFF0'))).not_to be_valid
        expect(Color.new(attributes.merge(hexcode: 'white'))).not_to be_valid
      end

      it 'fixes some wrong formats of hexcode automatically' do
        color = Color.new(attributes.merge(hexcode: 'FFCC33'))
        expect(color).to be_valid
        expect(color.hexcode).to eq('#FFCC33')

        color = Color.new(attributes.merge(hexcode: '#ffcc33'))
        expect(color).to be_valid
        expect(color.hexcode).to eq('#FFCC33')

        color = Color.new(attributes.merge(hexcode: 'fc3'))
        expect(color).to be_valid
        expect(color.hexcode).to eq('#FFCC33')

        color = Color.new(attributes.merge(hexcode: '#fc3'))
        expect(color).to be_valid
        expect(color.hexcode).to eq('#FFCC33')
      end

      it 'is valid w/ proper hexcodes' do
        expect(Color.new(attributes.merge(hexcode: '#FFFFFF'))).to be_valid
        expect(Color.new(attributes.merge(hexcode: '#FF00FF'))).to be_valid
      end
    end
  end
end
