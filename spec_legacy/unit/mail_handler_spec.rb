#-- encoding: UTF-8

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
require_relative '../legacy_spec_helper'

describe MailHandler, type: :model do
  fixtures :all

  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/mail_handler'

  it 'should add work package with attributes override' do
    issue = submit_email('ticket_with_attributes.eml', allow_override: 'type,category,priority')
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.type.to_s
    assert_equal 'Stock management', issue.category.to_s
    assert_equal 'Urgent', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  it 'should add work package with group assignment' do
    work_package = submit_email('ticket_on_given_project.eml') do |email|
      email.gsub!('Assigned to: John Smith', 'Assigned to: B Team')
    end
    assert work_package.is_a?(WorkPackage)
    assert !work_package.new_record?
    work_package.reload
    assert_equal Group.find(11), work_package.assigned_to
  end

  it 'should add work package with partial attributes override' do
    issue = submit_email('ticket_with_attributes.eml', issue: { priority: 'High' }, allow_override: ['type'])
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.type.to_s
    assert_nil issue.category
    assert_equal 'High', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  it 'should add work package with spaces between attribute and separator' do
    issue = submit_email('ticket_with_spaces_between_attribute_and_separator.eml', allow_override: 'type,category,priority')
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.type.to_s
    assert_equal 'Stock management', issue.category.to_s
    assert_equal 'Urgent', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  it 'should add work package with attachment to specific project' do
    issue = submit_email('ticket_with_attachment.eml', issue: { project: 'onlinestore' })
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'Ticket created by email with attachment', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'This is  a new ticket with attachments', issue.description
    # Attachment properties
    assert_equal 1, issue.attachments.size
    assert_equal 'Paella.jpg', issue.attachments.first.filename
    assert_equal 'image/jpeg', issue.attachments.first.content_type
    assert_equal 10790, issue.attachments.first.filesize
  end

  it 'should add work package with custom fields' do
    issue = submit_email('ticket_with_custom_fields.eml', issue: { project: 'onlinestore' })
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket with custom field values', issue.subject
    assert_equal 'Value for a custom field', issue.custom_value_for(CustomField.find_by(name: 'Searchable field')).value
    assert !issue.description.match(/^searchable field:/i)
  end

  it 'should add work package should match assignee on display name' do # added from redmine  - not sure if it is ok here
    user = create(:user, firstname: 'Foo', lastname: 'Bar')
    role = create(:role, name: 'Superhero')
    create(:member, user: user, project: Project.find(2), role_ids: [role.id])
    issue = submit_email('ticket_on_given_project.eml') do |email|
      email.sub!(/^Assigned to.*$/, 'Assigned to: Foo Bar')
    end
    assert issue.is_a?(WorkPackage)
    assert_equal user, issue.assigned_to
  end

  it 'should add work package by unknown user' do
    assert_no_difference 'User.count' do
      assert_equal false, submit_email('ticket_by_unknown_user.eml', issue: { project: 'ecookbook' })
    end
  end

  it 'should add work package by anonymous user' do
    Role.anonymous.add_permission!(:add_work_packages)
    assert_no_difference 'User.count' do
      issue = submit_email('ticket_by_unknown_user.eml', issue: { project: 'ecookbook' }, unknown_user: 'accept')
      assert issue.is_a?(WorkPackage)
      assert issue.author.anonymous?
    end
  end

  it 'should add work package by anonymous user with no from address' do
    Role.anonymous.add_permission!(:add_work_packages)
    assert_no_difference 'User.count' do
      issue = submit_email('ticket_by_empty_user.eml', issue: { project: 'ecookbook' }, unknown_user: 'accept')
      assert issue.is_a?(WorkPackage)
      assert issue.author.anonymous?
    end
  end

  it 'should add work package by anonymous user on private project' do
    Role.anonymous.add_permission!(:add_work_packages)
    assert_no_difference 'User.count' do
      assert_no_difference 'WorkPackage.count' do
        assert_equal false, submit_email('ticket_by_unknown_user.eml', issue: { project: 'onlinestore' }, unknown_user: 'accept')
      end
    end
  end

  it 'should add work package by anonymous user on private project without permission check' do
    assert_no_difference 'User.count' do
      assert_difference 'WorkPackage.count' do
        issue = submit_email('ticket_by_unknown_user.eml',
                             issue: { project: 'onlinestore' },
                             no_permission_check: '1',
                             unknown_user: 'accept')
        assert issue.is_a?(WorkPackage)
        assert issue.author.anonymous?
        assert !issue.project.public?
        assert issue.root?
        assert issue.leaf?
      end
    end
  end

  it 'should add work package without from header' do
    Role.anonymous.add_permission!(:add_work_packages)
    assert_equal false, submit_email('ticket_without_from_header.eml')
  end

  context 'without default start_date', with_settings: { work_package_startdate_is_adddate: false } do
    it 'should add work package with invalid attributes' do
      issue = submit_email('ticket_with_invalid_attributes.eml', allow_override: 'type,category,priority')
      assert issue.is_a?(WorkPackage)
      assert !issue.new_record?
      issue.reload
      assert_nil issue.assigned_to
      assert_nil issue.start_date
      assert_nil issue.due_date
      assert_equal 0, issue.done_ratio
      assert_equal 'Normal', issue.priority.to_s
      assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
    end
  end

  it 'should add work package with localized attributes' do
    User.find_by_mail('jsmith@somenet.foo').update_attribute 'language', 'de'

    issue = submit_email('ticket_with_localized_attributes.eml', allow_override: 'type,category,priority')
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.type.to_s
    assert_equal 'Stock management', issue.category.to_s
    assert_equal 'Urgent', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  it 'should add work package with japanese keywords' do
    type = ::Type.create!(name: '開発')
    Project.find(1).types << type
    issue = submit_email('japanese_keywords_iso_2022_jp.eml', issue: { project: 'ecookbook' }, allow_override: 'type')
    assert_kind_of WorkPackage, issue
    assert_equal type, issue.type
  end

  it 'should add from apple mail' do
    issue = submit_email(
      'apple_mail_with_attachment.eml',
      issue: { project: 'ecookbook' }
    )
    assert_kind_of WorkPackage, issue
    assert_equal 1, issue.attachments.size

    attachment = issue.attachments.first
    assert_equal 'paella.jpg', attachment.filename
    assert_equal 10790, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 10790, File.size(attachment.diskfile)
    assert_equal 'caaf384198bcbc9563ab5c058acd73cd', attachment.digest
  end

  it 'should add work package with iso 8859 1 subject' do
    issue = submit_email(
      'subject_as_iso-8859-1.eml',
      issue: { project: 'ecookbook' }
    )
    assert_kind_of WorkPackage, issue
    assert_equal 'Testmail from Webmail: ä ö ü...', issue.subject
  end

  it 'should ignore emails from locked users' do
    User.find(2).locked!

    expect_any_instance_of(MailHandler).to receive(:dispatch).never
    assert_no_difference 'WorkPackage.count' do
      assert_equal false, submit_email('ticket_on_given_project.eml')
    end
  end

  it 'should ignore auto replied emails' do
    expect_any_instance_of(MailHandler).to receive(:dispatch).never
    [
      'X-Auto-Response-Suppress: OOF',
      'Auto-Submitted: auto-replied',
      'Auto-Submitted: Auto-Replied',
      'Auto-Submitted: auto-generated'
    ].each do |header|
      raw = IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
      raw = header + "\n" + raw

      assert_no_difference 'WorkPackage.count' do
        assert_equal false, MailHandler.receive(raw), "email with #{header} header was not ignored"
      end
    end
  end

  it 'should strip tags of html only emails' do
    issue = submit_email('ticket_html_only.eml', issue: { project: 'ecookbook' })
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
    assert_equal 'HTML email', issue.subject
    assert_equal 'This is a html-only email.', issue.description
  end

  it 'should email with long subject line' do
    issue = submit_email('ticket_with_long_subject.eml')
    assert issue.is_a?(WorkPackage)
    assert_equal issue.subject,
                 'New ticket on a given project with a very long subject line which exceeds 255 chars and should not be ignored but chopped off. And if the subject line is still not long enough, we just add more text. And more text. Wow, this is really annoying. Especially, if you have nothing to say...'[
0, 255]
  end

  it 'should new user from attributes should return valid user' do
    to_test = {
      # [address, name] => [login, firstname, lastname]
      ['jsmith@example.net', nil] => ['jsmith@example.net', 'jsmith', '-'],
      ['jsmith@example.net', 'John'] => ['jsmith@example.net', 'John', '-'],
      ['jsmith@example.net', 'John Smith'] => ['jsmith@example.net', 'John', 'Smith'],
      ['jsmith@example.net', 'John Paul Smith'] => ['jsmith@example.net', 'John', 'Paul Smith'],
      ['jsmith@example.net',
       'AVeryLongFirstnameThatNoLongerExceedsTheMaximumLength Smith'] => ['jsmith@example.net',
                                                                          'AVeryLongFirstnameThatNoLongerExceedsTheMaximumLength', 'Smith'],
      ['jsmith@example.net',
       'John AVeryLongLastnameThatNoLongerExceedsTheMaximumLength'] => ['jsmith@example.net', 'John',
                                                                        'AVeryLongLastnameThatNoLongerExceedsTheMaximumLength']
    }

    to_test.each do |attrs, expected|
      user = MailHandler.new_user_from_attributes(attrs.first, attrs.last)

      assert user.valid?, user.errors.full_messages.to_s
      assert_equal attrs.first, user.mail
      assert_equal expected[0], user.login
      assert_equal expected[1], user.firstname
      assert_equal expected[2], user.lastname
    end
  end

  context 'with min password length',
          with_settings: { password_min_length: 15 } do
    it 'should new user from attributes should respect minimum password length' do
      user = MailHandler.new_user_from_attributes('jsmith@example.net')
      assert user.valid?
      assert user.password.length >= 15
    end
  end

  it 'should new user from attributes should use default login if invalid' do
    user = MailHandler.new_user_from_attributes('foo&bar@example.net')
    assert user.valid?
    assert user.login =~ /^user[a-f0-9]+$/
    assert_equal 'foo&bar@example.net', user.mail
  end

  it 'should new user with utf8 encoded fullname should be decoded' do
    assert_difference 'User.count' do
      issue = submit_email(
        'fullname_of_sender_as_utf8_encoded.eml',
        issue: { project: 'ecookbook' },
        unknown_user: 'create'
      )
    end

    user = User.order('id DESC').first
    assert_equal 'foo@example.org', user.mail
    str1 = "\xc3\x84\xc3\xa4"
    str2 = "\xc3\x96\xc3\xb6"
    str1.force_encoding('UTF-8') if str1.respond_to?(:force_encoding)
    str2.force_encoding('UTF-8') if str2.respond_to?(:force_encoding)
    assert_equal str1, user.firstname
    assert_equal str2, user.lastname
  end

  private

  def submit_email(filename, options = {})
    raw = IO.read(File.join(FIXTURES_PATH, filename))
    yield raw if block_given?
    MailHandler.receive(raw, options)
  end

  def assert_issue_created(issue)
    assert issue.is_a?(WorkPackage)
    assert !issue.new_record?
    issue.reload
  end
end
