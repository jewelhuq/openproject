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

require File.dirname(__FILE__) + '/../spec_helper'

describe DocumentsController do
  render_views

  let(:admin) { create(:admin) }
  let(:project) { create(:project, name: "Test Project") }
  let(:user) { create(:user) }
  let(:role) { create(:role, permissions: [:view_documents]) }

  let(:default_category) do
    create(:document_category, project: project, name: "Default Category")
  end

  let(:document) do
    create(:document, title: "Sample Document", project: project, category: default_category)
  end

  current_user { admin }

  describe "index" do
    let(:long_description) do
      <<-LOREM.strip_heredoc
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.\
        Ut egestas, mi vehicula varius varius, ipsum massa fermentum orci,\
        eget tristique ante sem vel mi. Nulla facilisi.\
        Donec enim libero, luctus ac sagittis sit amet, vehicula sagittis magna.\
        Duis ultrices molestie ante, eget scelerisque sem iaculis vitae.\
        Etiam fermentum mauris vitae metus pharetra condimentum fermentum est pretium.\
        Proin sollicitudin elementum quam quis pharetra.\
        Aenean facilisis nunc quis elit volutpat mollis.\
        Aenean eleifend varius euismod. Ut dolor est, congue eget dapibus eget, elementum eu odio.\
        Integer et lectus neque, nec scelerisque nisi. EndOfLineHere

        Praesent a nunc lorem, ac porttitor eros.
      LOREM
    end

    before do
      document.update(description: long_description)
      get :index, params: { project_id: project.identifier }
    end

    it "renders the index-template successfully" do
      expect(response).to be_successful
      expect(response).to render_template("index")
    end

    it "group documents by category, if no other sorting is given" do
      expect(assigns(:grouped)).not_to be_nil
      expect(assigns(:grouped).keys.map(&:name)).to eql [default_category.name]
    end

    it "renders documents with long descriptions properly" do
      expect(response.body).to have_selector('.wiki p', visible: :all)
      expect(response.body).to have_selector('.wiki p', visible: :all, text: (document.description.split("\n").first + '...'))
      expect(response.body).to have_selector('.wiki p', visible: :all, text: /EndOfLineHere.../)
    end
  end

  describe 'new' do
    before do
      get :new, params: { project_id: project.id }
    end

    it 'show the new document form' do
      expect(response).to render_template(partial: 'documents/_form')
    end
  end

  describe "create" do
    let(:document_attributes) do
      attributes_for(:document,
                     title: "New Document",
                     project_id: project.id,
                     category_id: default_category.id)
    end

    before do
      ActionMailer::Base.deliveries.clear
    end

    it "creates a new document with valid arguments" do
      expect do
        post :create,
             params: {
               project_id: project.identifier,
               document: attributes_for(
                 :document,
                 title: "New Document",
                 project_id: project.id,
                 category_id: default_category.id
               )
             }
      end.to change(Document, :count).by 1
    end

    it 'does trigger a workflow job for the document' do
      expect(Notifications::WorkflowJob)
        .to have_been_enqueued
              .with(:create_notifications, document.journals.last, true)
    end

    describe "with attachments" do
      let(:uncontainered) { create :attachment, container: nil, author: admin }

      before do
        notify_project = project
        create(:member, project: notify_project, user: user, roles: [role])

        post :create,
             params: {
               project_id: notify_project.identifier,
               document: attributes_for(:document,
                                        title: "New Document",
                                        project_id: notify_project.id,
                                        category_id: default_category.id),
               attachments: { '1' => { id: uncontainered.id } }
             }
      end

      it "adds an attachment" do
        document = Document.last

        expect(document.attachments.count).to eql 1
        attachment = document.attachments.first
        expect(uncontainered.reload).to eql attachment
      end

      it "redirects to the documents-page" do
        expect(response).to redirect_to project_documents_path(project.identifier)
      end
    end
  end

  describe 'show' do
    before do
      document
      get :show, params: { id: document.id }
    end

    it "shows the attachment" do
      expect(response).to be_successful
      expect(response).to render_template('show')
    end
  end

  describe "destroy" do
    before do
      document
    end

    it "deletes the document and redirect back to documents-page of the project" do
      expect do
        delete :destroy, params: { id: document.id }
      end.to change(Document, :count).by -1

      expect(response).to redirect_to "/projects/#{project.identifier}/documents"
      expect { Document.find(document.id) }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  def file_attachment
    test_document = "#{OpenProject::Documents::Engine.root}/spec/assets/attachments/testfile.txt"
    Rack::Test::UploadedFile.new(test_document, "text/plain")
  end
end
