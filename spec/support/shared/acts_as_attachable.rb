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

shared_examples_for 'acts_as_attachable included' do
  let(:attachment1) { create(:attachment, container: nil, author: current_user) }
  let(:attachment2) { create(:attachment, container: nil, author: current_user) }
  let(:instance_project) { respond_to?(:project) ? project : model_instance.project }
  let(:add_permission_user) do
    permission = if model_instance.persisted?
                   Array(described_class.attachable_options[:add_on_persisted_permission])
                 else
                   Array(described_class.attachable_options[:add_on_new_permission])
                 end
    create(:user,
           member_in_project: instance_project,
           member_with_permissions: permission)
  end
  let(:no_permission_user) do
    create(:user,
           member_in_project: instance_project,
           member_with_permissions: [])
  end
  let(:other_user) do
    create(:user)
  end
  let(:current_user) { add_permission_user }

  describe '#validations on attachments_claimed' do
    before do
      login_as(current_user)
    end

    context 'with no attachments_claimed' do
      it 'is valid' do
        expect(model_instance)
          .to be_valid
      end
    end

    context 'for attachments that are unattached, created by the current_user, ' +
            'added to attachments_claimed and the user having the permission' do
      it 'is valid' do
        model_instance.attachments_claimed = [attachment1, attachment2]

        expect(model_instance)
          .to be_valid
      end
    end

    context 'for attachments that are unattached, created by the current_user, ' +
            'added to attachments_claimed and the user not having the permission' do
      let(:current_user) { no_permission_user }

      it 'is invalid' do
        model_instance.attachments_claimed = [attachment1, attachment2]

        expect(model_instance)
          .to be_invalid

        expect(model_instance.errors.symbols_for(:attachments))
          .to match_array [:not_allowed]
      end
    end

    context 'for attachments that are attached, created by the current_user, ' +
            'added to attachments_claimed and the user having the permission' do
      let(:attachment1) { create(:attachment, author: current_user) }
      let(:attachment2) { create(:attachment, author: current_user) }

      it 'is invalid' do
        model_instance.attachments_claimed = [attachment1, attachment2]

        expect(model_instance)
          .to be_invalid

        expect(model_instance.errors.symbols_for(:attachments))
          .to match_array [:unchangeable]
      end
    end

    context 'for attachments that are unattached, not created by the current_user, ' +
            'added to attachments_claimed and the user having the permission' do
      let(:attachment1) { create(:attachment, container: nil, author: other_user) }
      let(:attachment2) { create(:attachment, container: nil, author: other_user) }

      it 'is invalid' do
        model_instance.attachments_claimed = [attachment1, attachment2]

        expect(model_instance)
          .to be_invalid

        expect(model_instance.errors.symbols_for(:attachments))
          .to match_array [:does_not_exist]
      end
    end
  end

  describe '#attachments_claimed' do
    before do
      login_as(add_permission_user)
      model_instance.attachments_claimed = [attachment1, attachment2]
    end

    it 'updates all attachments to be linked to the model before saving' do
      model_instance.save

      expect(model_instance.attachments.reload).to match_array [attachment1, attachment2]
      expect(attachment1.reload.container).to eql model_instance
      expect(attachment2.reload.container).to eql model_instance

      if described_class.journaled?
        expect(model_instance.journals.last.attachable_journals.map(&:attachment_id)).to match_array [attachment1.id,
                                                                                                      attachment2.id]
      end
    end
  end

  describe '#attachments_visible' do
    let!(:attachment1) { create(:attachment, container: model_instance, author: current_user) }

    it 'allows access to a logged user when viewable_by_all_users is set' do
      if model_instance.class.attachable_options[:viewable_by_all_users]
        expect(model_instance.attachments_visible?(other_user)).to eq true
        expect(attachment1.visible?(no_permission_user)).to eq true
      else
        expect(model_instance.attachments_visible?(other_user)).to eq false
        expect(attachment1.visible?(other_user)).to eq false
      end
    end
  end
end
