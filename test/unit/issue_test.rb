# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class IssueTest < ActiveSupport::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :versions,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  include Redmine::I18n

  def teardown
    User.current = nil
  end

  def test_create
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3,
                      :status_id => 1, :priority => IssuePriority.all.first,
                      :subject => 'test_create',
                      :description => 'IssueTest#test_create', :estimated_hours => '1:30')
    assert issue.save
    issue.reload
    assert_equal 1.5, issue.estimated_hours
  end

  def test_create_minimal
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3,
                      :status_id => 1, :priority => IssuePriority.all.first,
                      :subject => 'test_create')
    assert issue.save
    assert issue.description.nil?
    assert_nil issue.estimated_hours
  end

  def test_create_with_required_custom_field
    set_language_if_valid 'en'
    field = IssueCustomField.find_by_name('Database')
    field.update_attribute(:is_required, true)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :subject => 'test_create',
                      :description => 'IssueTest#test_create_with_required_custom_field')
    assert issue.available_custom_fields.include?(field)
    # No value for the custom field
    assert !issue.save
    assert_equal ["Database can't be blank"], issue.errors.full_messages
    # Blank value
    issue.custom_field_values = { field.id => '' }
    assert !issue.save
    assert_equal ["Database can't be blank"], issue.errors.full_messages
    # Invalid value
    issue.custom_field_values = { field.id => 'SQLServer' }
    assert !issue.save
    assert_equal ["Database is not included in the list"], issue.errors.full_messages
    # Valid value
    issue.custom_field_values = { field.id => 'PostgreSQL' }
    assert issue.save
    issue.reload
    assert_equal 'PostgreSQL', issue.custom_value_for(field).value
  end

  def test_create_with_group_assignment
    with_settings :issue_group_assignment => '1' do
      assert Issue.new(:project_id => 2, :tracker_id => 1, :author_id => 1,
                       :subject => 'Group assignment',
                       :assigned_to_id => 11).save
      issue = Issue.first(:order => 'id DESC')
      assert_kind_of Group, issue.assigned_to
      assert_equal Group.find(11), issue.assigned_to
    end
  end

  def assert_visibility_match(user, issues)
    assert_equal issues.collect(&:id).sort, Issue.all.select {|issue| issue.visible?(user)}.collect(&:id).sort
  end

  def test_visible_scope_for_anonymous
    # Anonymous user should see issues of public projects only
    issues = Issue.visible(User.anonymous).all
    assert issues.any?
    assert_nil issues.detect {|issue| !issue.project.is_public?}
    assert_nil issues.detect {|issue| issue.is_private?}
    assert_visibility_match User.anonymous, issues
  end

  def test_visible_scope_for_anonymous_without_view_issues_permissions
    # Anonymous user should not see issues without permission
    Role.anonymous.remove_permission!(:view_issues)
    issues = Issue.visible(User.anonymous).all
    assert issues.empty?
    assert_visibility_match User.anonymous, issues
  end

  def test_anonymous_should_not_see_private_issues_with_issues_visibility_set_to_default
    assert Role.anonymous.update_attribute(:issues_visibility, 'default')
    issue = Issue.generate_for_project!(Project.find(1), :author => User.anonymous, :assigned_to => User.anonymous, :is_private => true)
    assert_nil Issue.where(:id => issue.id).visible(User.anonymous).first
    assert !issue.visible?(User.anonymous)
  end

  def test_anonymous_should_not_see_private_issues_with_issues_visibility_set_to_own
    assert Role.anonymous.update_attribute(:issues_visibility, 'own')
    issue = Issue.generate_for_project!(Project.find(1), :author => User.anonymous, :assigned_to => User.anonymous, :is_private => true)
    assert_nil Issue.where(:id => issue.id).visible(User.anonymous).first
    assert !issue.visible?(User.anonymous)
  end

  def test_visible_scope_for_non_member
    user = User.find(9)
    assert user.projects.empty?
    # Non member user should see issues of public projects only
    issues = Issue.visible(user).all
    assert issues.any?
    assert_nil issues.detect {|issue| !issue.project.is_public?}
    assert_nil issues.detect {|issue| issue.is_private?}
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_non_member_with_own_issues_visibility
    Role.non_member.update_attribute :issues_visibility, 'own'
    Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 9, :subject => 'Issue by non member')
    user = User.find(9)

    issues = Issue.visible(user).all
    assert issues.any?
    assert_nil issues.detect {|issue| issue.author != user}
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_non_member_without_view_issues_permissions
    # Non member user should not see issues without permission
    Role.non_member.remove_permission!(:view_issues)
    user = User.find(9)
    assert user.projects.empty?
    issues = Issue.visible(user).all
    assert issues.empty?
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_member
    user = User.find(9)
    # User should see issues of projects for which he has view_issues permissions only
    Role.non_member.remove_permission!(:view_issues)
    Member.create!(:principal => user, :project_id => 3, :role_ids => [2])
    issues = Issue.visible(user).all
    assert issues.any?
    assert_nil issues.detect {|issue| issue.project_id != 3}
    assert_nil issues.detect {|issue| issue.is_private?}
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_member_with_groups_should_return_assigned_issues
    user = User.find(8)
    assert user.groups.any?
    Member.create!(:principal => user.groups.first, :project_id => 1, :role_ids => [2])
    Role.non_member.remove_permission!(:view_issues)
    
    issue = Issue.create(:project_id => 1, :tracker_id => 1, :author_id => 3,
      :status_id => 1, :priority => IssuePriority.all.first,
      :subject => 'Assignment test',
      :assigned_to => user.groups.first,
      :is_private => true)
    
    Role.find(2).update_attribute :issues_visibility, 'default'
    issues = Issue.visible(User.find(8)).all
    assert issues.any?
    assert issues.include?(issue)
    
    Role.find(2).update_attribute :issues_visibility, 'own'
    issues = Issue.visible(User.find(8)).all
    assert issues.any?
    assert issues.include?(issue)
  end

  def test_visible_scope_for_admin
    user = User.find(1)
    user.members.each(&:destroy)
    assert user.projects.empty?
    issues = Issue.visible(user).all
    assert issues.any?
    # Admin should see issues on private projects that he does not belong to
    assert issues.detect {|issue| !issue.project.is_public?}
    # Admin should see private issues of other users
    assert issues.detect {|issue| issue.is_private? && issue.author != user}
    assert_visibility_match user, issues
  end

  def test_visible_scope_with_project
    project = Project.find(1)
    issues = Issue.visible(User.find(2), :project => project).all
    projects = issues.collect(&:project).uniq
    assert_equal 1, projects.size
    assert_equal project, projects.first
  end

  def test_visible_scope_with_project_and_subprojects
    project = Project.find(1)
    issues = Issue.visible(User.find(2), :project => project, :with_subprojects => true).all
    projects = issues.collect(&:project).uniq
    assert projects.size > 1
    assert_equal [], projects.select {|p| !p.is_or_is_descendant_of?(project)}
  end

  def test_visible_and_nested_set_scopes
    assert_equal 0, Issue.find(1).descendants.visible.all.size
  end

  def test_open_scope
    issues = Issue.open.all
    assert_nil issues.detect(&:closed?)
  end

  def test_open_scope_with_arg
    issues = Issue.open(false).all
    assert_equal issues, issues.select(&:closed?)
  end

  def test_errors_full_messages_should_include_custom_fields_errors
    field = IssueCustomField.find_by_name('Database')

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :subject => 'test_create',
                      :description => 'IssueTest#test_create_with_required_custom_field')
    assert issue.available_custom_fields.include?(field)
    # Invalid value
    issue.custom_field_values = { field.id => 'SQLServer' }

    assert !issue.valid?
    assert_equal 1, issue.errors.full_messages.size
    assert_equal "Database #{I18n.translate('activerecord.errors.messages.inclusion')}",
                 issue.errors.full_messages.first
  end

  def test_update_issue_with_required_custom_field
    field = IssueCustomField.find_by_name('Database')
    field.update_attribute(:is_required, true)

    issue = Issue.find(1)
    assert_nil issue.custom_value_for(field)
    assert issue.available_custom_fields.include?(field)
    # No change to custom values, issue can be saved
    assert issue.save
    # Blank value
    issue.custom_field_values = { field.id => '' }
    assert !issue.save
    # Valid value
    issue.custom_field_values = { field.id => 'PostgreSQL' }
    assert issue.save
    issue.reload
    assert_equal 'PostgreSQL', issue.custom_value_for(field).value
  end

  def test_should_not_update_attributes_if_custom_fields_validation_fails
    issue = Issue.find(1)
    field = IssueCustomField.find_by_name('Database')
    assert issue.available_custom_fields.include?(field)

    issue.custom_field_values = { field.id => 'Invalid' }
    issue.subject = 'Should be not be saved'
    assert !issue.save

    issue.reload
    assert_equal "Can't print recipes", issue.subject
  end

  def test_should_not_recreate_custom_values_objects_on_update
    field = IssueCustomField.find_by_name('Database')

    issue = Issue.find(1)
    issue.custom_field_values = { field.id => 'PostgreSQL' }
    assert issue.save
    custom_value = issue.custom_value_for(field)
    issue.reload
    issue.custom_field_values = { field.id => 'MySQL' }
    assert issue.save
    issue.reload
    assert_equal custom_value.id, issue.custom_value_for(field).id
  end

  def test_should_not_update_custom_fields_on_changing_tracker_with_different_custom_fields
    issue = Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :subject => 'Test', :custom_field_values => {'2' => 'Test'})
    assert !Tracker.find(2).custom_field_ids.include?(2)

    issue = Issue.find(issue.id)
    issue.attributes = {:tracker_id => 2, :custom_field_values => {'1' => ''}}

    issue = Issue.find(issue.id)
    custom_value = issue.custom_value_for(2)
    assert_not_nil custom_value
    assert_equal 'Test', custom_value.value
  end

  def test_assigning_tracker_id_should_reload_custom_fields_values
    issue = Issue.new(:project => Project.find(1))
    assert issue.custom_field_values.empty?
    issue.tracker_id = 1
    assert issue.custom_field_values.any?
  end

  def test_assigning_attributes_should_assign_project_and_tracker_first
    seq = sequence('seq')
    issue = Issue.new
    issue.expects(:project_id=).in_sequence(seq)
    issue.expects(:tracker_id=).in_sequence(seq)
    issue.expects(:subject=).in_sequence(seq)
    issue.attributes = {:tracker_id => 2, :project_id => 1, :subject => 'Test'}
  end

  def test_assigning_tracker_and_custom_fields_should_assign_custom_fields
    attributes = ActiveSupport::OrderedHash.new
    attributes['custom_field_values'] = { '1' => 'MySQL' }
    attributes['tracker_id'] = '1'
    issue = Issue.new(:project => Project.find(1))
    issue.attributes = attributes
    assert_equal 'MySQL', issue.custom_field_value(1)
  end

  def test_should_update_issue_with_disabled_tracker
    p = Project.find(1)
    issue = Issue.find(1)

    p.trackers.delete(issue.tracker)
    assert !p.trackers.include?(issue.tracker)

    issue.reload
    issue.subject = 'New subject'
    assert issue.save
  end

  def test_should_not_set_a_disabled_tracker
    p = Project.find(1)
    p.trackers.delete(Tracker.find(2))

    issue = Issue.find(1)
    issue.tracker_id = 2
    issue.subject = 'New subject'
    assert !issue.save
    assert_not_nil issue.errors[:tracker_id]
  end

  def test_category_based_assignment
    issue = Issue.create(:project_id => 1, :tracker_id => 1, :author_id => 3,
                         :status_id => 1, :priority => IssuePriority.all.first,
                         :subject => 'Assignment test',
                         :description => 'Assignment test', :category_id => 1)
    assert_equal IssueCategory.find(1).assigned_to, issue.assigned_to
  end

  def test_new_statuses_allowed_to
    WorkflowTransition.delete_all

    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 2, :author => false, :assignee => false)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 3, :author => true, :assignee => false)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 4, :author => false, :assignee => true)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :new_status_id => 5, :author => true, :assignee => true)
    status = IssueStatus.find(1)
    role = Role.find(1)
    tracker = Tracker.find(1)
    user = User.find(2)

    issue = Issue.generate!(:tracker => tracker, :status => status, :project_id => 1, :author_id => 1)
    assert_equal [1, 2], issue.new_statuses_allowed_to(user).map(&:id)

    issue = Issue.generate!(:tracker => tracker, :status => status, :project_id => 1, :author => user)
    assert_equal [1, 2, 3, 5], issue.new_statuses_allowed_to(user).map(&:id)

    issue = Issue.generate!(:tracker => tracker, :status => status, :project_id => 1, :author_id => 1, :assigned_to => user)
    assert_equal [1, 2, 4, 5], issue.new_statuses_allowed_to(user).map(&:id)

    issue = Issue.generate!(:tracker => tracker, :status => status, :project_id => 1, :author => user, :assigned_to => user)
    assert_equal [1, 2, 3, 4, 5], issue.new_statuses_allowed_to(user).map(&:id)
  end

  def test_new_statuses_allowed_to_should_return_all_transitions_for_admin
    admin = User.find(1)
    issue = Issue.find(1)
    assert !admin.member_of?(issue.project)
    expected_statuses = [issue.status] + WorkflowTransition.find_all_by_old_status_id(issue.status_id).map(&:new_status).uniq.sort

    assert_equal expected_statuses, issue.new_statuses_allowed_to(admin)
  end

  def test_new_statuses_allowed_to_should_return_default_and_current_status_when_copying
    issue = Issue.find(1).copy
    assert_equal [1], issue.new_statuses_allowed_to(User.find(2)).map(&:id)

    issue = Issue.find(2).copy
    assert_equal [1, 2], issue.new_statuses_allowed_to(User.find(2)).map(&:id)
  end

  def test_safe_attributes_names_should_not_include_disabled_field
    tracker = Tracker.new(:core_fields => %w(assigned_to_id fixed_version_id))

    issue = Issue.new(:tracker => tracker)
    assert_include 'tracker_id', issue.safe_attribute_names
    assert_include 'status_id', issue.safe_attribute_names
    assert_include 'subject', issue.safe_attribute_names
    assert_include 'description', issue.safe_attribute_names
    assert_include 'custom_field_values', issue.safe_attribute_names
    assert_include 'custom_fields', issue.safe_attribute_names
    assert_include 'lock_version', issue.safe_attribute_names

    tracker.core_fields.each do |field|
      assert_include field, issue.safe_attribute_names
    end

    tracker.disabled_core_fields.each do |field|
      assert_not_include field, issue.safe_attribute_names
    end
  end

  def test_safe_attributes_should_ignore_disabled_fields
    tracker = Tracker.find(1)
    tracker.core_fields = %w(assigned_to_id due_date)
    tracker.save!

    issue = Issue.new(:tracker => tracker)
    issue.safe_attributes = {'start_date' => '2012-07-14', 'due_date' => '2012-07-14'}
    assert_nil issue.start_date
    assert_equal Date.parse('2012-07-14'), issue.due_date
  end

  def test_safe_attributes_should_accept_target_tracker_enabled_fields
    source = Tracker.find(1)
    source.core_fields = []
    source.save!
    target = Tracker.find(2)
    target.core_fields = %w(assigned_to_id due_date)
    target.save!

    issue = Issue.new(:tracker => source)
    issue.safe_attributes = {'tracker_id' => 2, 'due_date' => '2012-07-14'}
    assert_equal target, issue.tracker
    assert_equal Date.parse('2012-07-14'), issue.due_date
  end

  def test_safe_attributes_should_not_include_readonly_fields
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1)
    assert_equal %w(due_date), issue.read_only_attribute_names(user)
    assert_not_include 'due_date', issue.safe_attribute_names(user)

    issue.send :safe_attributes=, {'start_date' => '2012-07-14', 'due_date' => '2012-07-14'}, user
    assert_equal Date.parse('2012-07-14'), issue.start_date
    assert_nil issue.due_date
  end

  def test_safe_attributes_should_not_include_readonly_custom_fields
    cf1 = IssueCustomField.create!(:name => 'Writable field', :field_format => 'string', :is_for_all => true, :tracker_ids => [1])
    cf2 = IssueCustomField.create!(:name => 'Readonly field', :field_format => 'string', :is_for_all => true, :tracker_ids => [1])

    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1)
    assert_equal [cf2.id.to_s], issue.read_only_attribute_names(user)
    assert_not_include cf2.id.to_s, issue.safe_attribute_names(user)

    issue.send :safe_attributes=, {'custom_field_values' => {cf1.id.to_s => 'value1', cf2.id.to_s => 'value2'}}, user
    assert_equal 'value1', issue.custom_field_value(cf1)
    assert_nil issue.custom_field_value(cf2)

    issue.send :safe_attributes=, {'custom_fields' => [{'id' => cf1.id.to_s, 'value' => 'valuea'}, {'id' => cf2.id.to_s, 'value' => 'valueb'}]}, user
    assert_equal 'valuea', issue.custom_field_value(cf1)
    assert_nil issue.custom_field_value(cf2)
  end

  def test_editable_custom_field_values_should_return_non_readonly_custom_values
    cf1 = IssueCustomField.create!(:name => 'Writable field', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    cf2 = IssueCustomField.create!(:name => 'Readonly field', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])

    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1)
    values = issue.editable_custom_field_values(user)
    assert values.detect {|value| value.custom_field == cf1}
    assert_nil values.detect {|value| value.custom_field == cf2}

    issue.tracker_id = 2
    values = issue.editable_custom_field_values(user)
    assert values.detect {|value| value.custom_field == cf1}
    assert values.detect {|value| value.custom_field == cf2}
  end

  def test_safe_attributes_should_accept_target_tracker_writable_fields
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => 'start_date', :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    issue.send :safe_attributes=, {'start_date' => '2012-07-12', 'due_date' => '2012-07-14'}, user
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_nil issue.due_date

    issue.send :safe_attributes=, {'start_date' => '2012-07-15', 'due_date' => '2012-07-16', 'tracker_id' => 2}, user
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_equal Date.parse('2012-07-16'), issue.due_date
  end

  def test_safe_attributes_should_accept_target_status_writable_fields
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 2, :tracker_id => 1, :role_id => 1, :field_name => 'start_date', :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    issue.send :safe_attributes=, {'start_date' => '2012-07-12', 'due_date' => '2012-07-14'}, user
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_nil issue.due_date

    issue.send :safe_attributes=, {'start_date' => '2012-07-15', 'due_date' => '2012-07-16', 'status_id' => 2}, user
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_equal Date.parse('2012-07-16'), issue.due_date
  end

  def test_required_attributes_should_be_validated
    cf = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])

    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'category_id', :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => cf.id.to_s, :rule => 'required')

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => 'start_date', :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => cf.id.to_s, :rule => 'required')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1, :subject => 'Required fields', :author => user)
    assert_equal [cf.id.to_s, "category_id", "due_date"], issue.required_attribute_names(user).sort
    assert !issue.save, "Issue was saved"
    assert_equal ["Category can't be blank", "Due date can't be blank", "Foo can't be blank"], issue.errors.full_messages.sort

    issue.tracker_id = 2
    assert_equal [cf.id.to_s, "start_date"], issue.required_attribute_names(user).sort
    assert !issue.save, "Issue was saved"
    assert_equal ["Foo can't be blank", "Start date can't be blank"], issue.errors.full_messages.sort

    issue.start_date = Date.today
    issue.custom_field_values = {cf.id.to_s => 'bar'}
    assert issue.save
  end

  def test_required_attribute_names_for_multiple_roles_should_intersect_rules
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'start_date', :rule => 'required')
    user = User.find(2)
    member = Member.find(1)
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    assert_equal %w(due_date start_date), issue.required_attribute_names(user).sort

    member.role_ids = [1, 2]
    member.save!
    assert_equal [], issue.required_attribute_names(user.reload)

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 2, :field_name => 'due_date', :rule => 'required')
    assert_equal %w(due_date), issue.required_attribute_names(user)

    member.role_ids = [1, 2, 3]
    member.save!
    assert_equal [], issue.required_attribute_names(user.reload)

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 2, :field_name => 'due_date', :rule => 'readonly')
    # required + readonly => required
    assert_equal %w(due_date), issue.required_attribute_names(user)
  end

  def test_read_only_attribute_names_for_multiple_roles_should_intersect_rules
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'start_date', :rule => 'readonly')
    user = User.find(2)
    member = Member.find(1)
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    assert_equal %w(due_date start_date), issue.read_only_attribute_names(user).sort

    member.role_ids = [1, 2]
    member.save!
    assert_equal [], issue.read_only_attribute_names(user.reload)

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 2, :field_name => 'due_date', :rule => 'readonly')
    assert_equal %w(due_date), issue.read_only_attribute_names(user)
  end

  def test_copy
    issue = Issue.new.copy_from(1)
    assert issue.copy?
    assert issue.save
    issue.reload
    orig = Issue.find(1)
    assert_equal orig.subject, issue.subject
    assert_equal orig.tracker, issue.tracker
    assert_equal "125", issue.custom_value_for(2).value
  end

  def test_copy_should_copy_status
    orig = Issue.find(8)
    assert orig.status != IssueStatus.default

    issue = Issue.new.copy_from(orig)
    assert issue.save
    issue.reload
    assert_equal orig.status, issue.status
  end

  def test_copy_should_copy_subtasks
    issue = Issue.generate_with_descendants!(Project.find(1), :subject => 'Parent')

    copy = issue.reload.copy
    copy.author = User.find(7)
    assert_difference 'Issue.count', 1+issue.descendants.count do
      assert copy.save
    end
    copy.reload
    assert_equal %w(Child1 Child2), copy.children.map(&:subject).sort
    child_copy = copy.children.detect {|c| c.subject == 'Child1'}
    assert_equal %w(Child11), child_copy.children.map(&:subject).sort
    assert_equal copy.author, child_copy.author
  end

  def test_copy_should_copy_subtasks_to_target_project
    issue = Issue.generate_with_descendants!(Project.find(1), :subject => 'Parent')

    copy = issue.copy(:project_id => 3)
    assert_difference 'Issue.count', 1+issue.descendants.count do
      assert copy.save
    end
    assert_equal [3], copy.reload.descendants.map(&:project_id).uniq
  end

  def test_copy_should_not_copy_subtasks_twice_when_saving_twice
    issue = Issue.generate_with_descendants!(Project.find(1), :subject => 'Parent')

    copy = issue.reload.copy
    assert_difference 'Issue.count', 1+issue.descendants.count do
      assert copy.save
      assert copy.save
    end
  end

  def test_should_not_call_after_project_change_on_creation
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1, :subject => 'Test', :author_id => 1)
    issue.expects(:after_project_change).never
    issue.save!
  end

  def test_should_not_call_after_project_change_on_update
    issue = Issue.find(1)
    issue.project = Project.find(1)
    issue.subject = 'No project change'
    issue.expects(:after_project_change).never
    issue.save!
  end

  def test_should_call_after_project_change_on_project_change
    issue = Issue.find(1)
    issue.project = Project.find(2)
    issue.expects(:after_project_change).once
    issue.save!
  end

  def test_adding_journal_should_update_timestamp
    issue = Issue.find(1)
    updated_on_was = issue.updated_on

    issue.init_journal(User.first, "Adding notes")
    assert_difference 'Journal.count' do
      assert issue.save
    end
    issue.reload

    assert_not_equal updated_on_was, issue.updated_on
  end

  def test_should_close_duplicates
    # Create 3 issues
    project = Project.find(1)
    issue1 = Issue.generate_for_project!(project)
    issue2 = Issue.generate_for_project!(project)
    issue3 = Issue.generate_for_project!(project)

    # 2 is a dupe of 1
    IssueRelation.create!(:issue_from => issue2, :issue_to => issue1, :relation_type => IssueRelation::TYPE_DUPLICATES)
    # And 3 is a dupe of 2
    IssueRelation.create!(:issue_from => issue3, :issue_to => issue2, :relation_type => IssueRelation::TYPE_DUPLICATES)
    # And 3 is a dupe of 1 (circular duplicates)
    IssueRelation.create!(:issue_from => issue3, :issue_to => issue1, :relation_type => IssueRelation::TYPE_DUPLICATES)

    assert issue1.reload.duplicates.include?(issue2)

    # Closing issue 1
    issue1.init_journal(User.find(:first), "Closing issue1")
    issue1.status = IssueStatus.find :first, :conditions => {:is_closed => true}
    assert issue1.save
    # 2 and 3 should be also closed
    assert issue2.reload.closed?
    assert issue3.reload.closed?
  end

  def test_should_not_close_duplicated_issue
    project = Project.find(1)
    issue1 = Issue.generate_for_project!(project)
    issue2 = Issue.generate_for_project!(project)

    # 2 is a dupe of 1
    IssueRelation.create(:issue_from => issue2, :issue_to => issue1, :relation_type => IssueRelation::TYPE_DUPLICATES)
    # 2 is a dup of 1 but 1 is not a duplicate of 2
    assert !issue2.reload.duplicates.include?(issue1)

    # Closing issue 2
    issue2.init_journal(User.find(:first), "Closing issue2")
    issue2.status = IssueStatus.find :first, :conditions => {:is_closed => true}
    assert issue2.save
    # 1 should not be also closed
    assert !issue1.reload.closed?
  end

  def test_assignable_versions
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :fixed_version_id => 1, :subject => 'New issue')
    assert_equal ['open'], issue.assignable_versions.collect(&:status).uniq
  end

  def test_should_not_be_able_to_assign_a_new_issue_to_a_closed_version
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :fixed_version_id => 1, :subject => 'New issue')
    assert !issue.save
    assert_not_nil issue.errors[:fixed_version_id]
  end

  def test_should_not_be_able_to_assign_a_new_issue_to_a_locked_version
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :fixed_version_id => 2, :subject => 'New issue')
    assert !issue.save
    assert_not_nil issue.errors[:fixed_version_id]
  end

  def test_should_be_able_to_assign_a_new_issue_to_an_open_version
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :fixed_version_id => 3, :subject => 'New issue')
    assert issue.save
  end

  def test_should_be_able_to_update_an_issue_assigned_to_a_closed_version
    issue = Issue.find(11)
    assert_equal 'closed', issue.fixed_version.status
    issue.subject = 'Subject changed'
    assert issue.save
  end

  def test_should_not_be_able_to_reopen_an_issue_assigned_to_a_closed_version
    issue = Issue.find(11)
    issue.status_id = 1
    assert !issue.save
    assert_not_nil issue.errors[:base]
  end

  def test_should_be_able_to_reopen_and_reassign_an_issue_assigned_to_a_closed_version
    issue = Issue.find(11)
    issue.status_id = 1
    issue.fixed_version_id = 3
    assert issue.save
  end

  def test_should_be_able_to_reopen_an_issue_assigned_to_a_locked_version
    issue = Issue.find(12)
    assert_equal 'locked', issue.fixed_version.status
    issue.status_id = 1
    assert issue.save
  end

  def test_should_not_be_able_to_keep_unshared_version_when_changing_project
    issue = Issue.find(2)
    assert_equal 2, issue.fixed_version_id
    issue.project_id = 3
    assert_nil issue.fixed_version_id
    issue.fixed_version_id = 2
    assert !issue.save
    assert_include 'Target version is not included in the list', issue.errors.full_messages
  end

  def test_should_keep_shared_version_when_changing_project
    Version.find(2).update_attribute :sharing, 'tree'
 
    issue = Issue.find(2)
    assert_equal 2, issue.fixed_version_id
    issue.project_id = 3
    assert_equal 2, issue.fixed_version_id
    assert issue.save
  end

  def test_allowed_target_projects_on_move_should_include_projects_with_issue_tracking_enabled
    assert_include Project.find(2), Issue.allowed_target_projects_on_move(User.find(2))
  end

  def test_allowed_target_projects_on_move_should_not_include_projects_with_issue_tracking_disabled
    Project.find(2).disable_module! :issue_tracking
    assert_not_include Project.find(2), Issue.allowed_target_projects_on_move(User.find(2))
  end

  def test_move_to_another_project_with_same_category
    issue = Issue.find(1)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Category changes
    assert_equal 4, issue.category_id
    # Make sure time entries were move to the target project
    assert_equal 2, issue.time_entries.first.project_id
  end

  def test_move_to_another_project_without_same_category
    issue = Issue.find(2)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Category cleared
    assert_nil issue.category_id
  end

  def test_move_to_another_project_should_clear_fixed_version_when_not_shared
    issue = Issue.find(1)
    issue.update_attribute(:fixed_version_id, 1)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Cleared fixed_version
    assert_equal nil, issue.fixed_version
  end

  def test_move_to_another_project_should_keep_fixed_version_when_shared_with_the_target_project
    issue = Issue.find(1)
    issue.update_attribute(:fixed_version_id, 4)
    issue.project = Project.find(5)
    assert issue.save
    issue.reload
    assert_equal 5, issue.project_id
    # Keep fixed_version
    assert_equal 4, issue.fixed_version_id
  end

  def test_move_to_another_project_should_clear_fixed_version_when_not_shared_with_the_target_project
    issue = Issue.find(1)
    issue.update_attribute(:fixed_version_id, 1)
    issue.project = Project.find(5)
    assert issue.save
    issue.reload
    assert_equal 5, issue.project_id
    # Cleared fixed_version
    assert_equal nil, issue.fixed_version
  end

  def test_move_to_another_project_should_keep_fixed_version_when_shared_systemwide
    issue = Issue.find(1)
    issue.update_attribute(:fixed_version_id, 7)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Keep fixed_version
    assert_equal 7, issue.fixed_version_id
  end

  def test_move_to_another_project_with_disabled_tracker
    issue = Issue.find(1)
    target = Project.find(2)
    target.tracker_ids = [3]
    target.save
    issue.project = target
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    assert_equal 3, issue.tracker_id
  end

  def test_copy_to_the_same_project
    issue = Issue.find(1)
    copy = issue.copy
    assert_difference 'Issue.count' do
      copy.save!
    end
    assert_kind_of Issue, copy
    assert_equal issue.project, copy.project
    assert_equal "125", copy.custom_value_for(2).value
  end

  def test_copy_to_another_project_and_tracker
    issue = Issue.find(1)
    copy = issue.copy(:project_id => 3, :tracker_id => 2)
    assert_difference 'Issue.count' do
      copy.save!
    end
    copy.reload
    assert_kind_of Issue, copy
    assert_equal Project.find(3), copy.project
    assert_equal Tracker.find(2), copy.tracker
    # Custom field #2 is not associated with target tracker
    assert_nil copy.custom_value_for(2)
  end

  context "#copy" do
    setup do
      @issue = Issue.find(1)
    end

    should "not create a journal" do
      copy = @issue.copy(:project_id => 3, :tracker_id => 2, :assigned_to_id => 3)
      copy.save!
      assert_equal 0, copy.reload.journals.size
    end

    should "allow assigned_to changes" do
      copy = @issue.copy(:project_id => 3, :tracker_id => 2, :assigned_to_id => 3)
      assert_equal 3, copy.assigned_to_id
    end

    should "allow status changes" do
      copy = @issue.copy(:project_id => 3, :tracker_id => 2, :status_id => 2)
      assert_equal 2, copy.status_id
    end

    should "allow start date changes" do
      date = Date.today
      copy = @issue.copy(:project_id => 3, :tracker_id => 2, :start_date => date)
      assert_equal date, copy.start_date
    end

    should "allow due date changes" do
      date = Date.today
      copy = @issue.copy(:project_id => 3, :tracker_id => 2, :due_date => date)
      assert_equal date, copy.due_date
    end

    should "set current user as author" do
      User.current = User.find(9)
      copy = @issue.copy(:project_id => 3, :tracker_id => 2)
      assert_equal User.current, copy.author
    end

    should "create a journal with notes" do
      date = Date.today
      notes = "Notes added when copying"
      copy = @issue.copy(:project_id => 3, :tracker_id => 2, :start_date => date)
      copy.init_journal(User.current, notes)
      copy.save!

      assert_equal 1, copy.journals.size
      journal = copy.journals.first
      assert_equal 0, journal.details.size
      assert_equal notes, journal.notes
    end
  end

  def test_recipients_should_include_previous_assignee
    user = User.find(3)
    user.members.update_all ["mail_notification = ?", false]
    user.update_attribute :mail_notification, 'only_assigned'

    issue = Issue.find(2)
    issue.assigned_to = nil
    assert_include user.mail, issue.recipients
    issue.save!
    assert !issue.recipients.include?(user.mail)
  end

  def test_recipients_should_not_include_users_that_cannot_view_the_issue
    issue = Issue.find(12)
    assert issue.recipients.include?(issue.author.mail)
    # copy the issue to a private project
    copy  = issue.copy(:project_id => 5, :tracker_id => 2)
    # author is not a member of project anymore
    assert !copy.recipients.include?(copy.author.mail)
  end

  def test_recipients_should_include_the_assigned_group_members
    group_member = User.generate!
    group = Group.generate!
    group.users << group_member

    issue = Issue.find(12)
    issue.assigned_to = group
    assert issue.recipients.include?(group_member.mail)
  end

  def test_watcher_recipients_should_not_include_users_that_cannot_view_the_issue
    user = User.find(3)
    issue = Issue.find(9)
    Watcher.create!(:user => user, :watchable => issue)
    assert issue.watched_by?(user)
    assert !issue.watcher_recipients.include?(user.mail)
  end

  def test_issue_destroy
    Issue.find(1).destroy
    assert_nil Issue.find_by_id(1)
    assert_nil TimeEntry.find_by_issue_id(1)
  end

  def test_destroying_a_deleted_issue_should_not_raise_an_error
    issue = Issue.find(1)
    Issue.find(1).destroy

    assert_nothing_raised do
      assert_no_difference 'Issue.count' do
        issue.destroy
      end
      assert issue.destroyed?
    end
  end

  def test_destroying_a_stale_issue_should_not_raise_an_error
    issue = Issue.find(1)
    Issue.find(1).update_attribute :subject, "Updated"

    assert_nothing_raised do
      assert_difference 'Issue.count', -1 do
        issue.destroy
      end
      assert issue.destroyed?
    end
  end

  def test_blocked
    blocked_issue = Issue.find(9)
    blocking_issue = Issue.find(10)

    assert blocked_issue.blocked?
    assert !blocking_issue.blocked?
  end

  def test_blocked_issues_dont_allow_closed_statuses
    blocked_issue = Issue.find(9)

    allowed_statuses = blocked_issue.new_statuses_allowed_to(users(:users_002))
    assert !allowed_statuses.empty?
    closed_statuses = allowed_statuses.select {|st| st.is_closed?}
    assert closed_statuses.empty?
  end

  def test_unblocked_issues_allow_closed_statuses
    blocking_issue = Issue.find(10)

    allowed_statuses = blocking_issue.new_statuses_allowed_to(users(:users_002))
    assert !allowed_statuses.empty?
    closed_statuses = allowed_statuses.select {|st| st.is_closed?}
    assert !closed_statuses.empty?
  end

  def test_rescheduling_an_issue_should_reschedule_following_issue
    issue1 = Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :subject => '-', :start_date => Date.today, :due_date => Date.today + 2)
    issue2 = Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 1, :status_id => 1, :subject => '-', :start_date => Date.today, :due_date => Date.today + 2)
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2, :relation_type => IssueRelation::TYPE_PRECEDES)
    assert_equal issue1.due_date + 1, issue2.reload.start_date

    issue1.due_date = Date.today + 5
    issue1.save!
    assert_equal issue1.due_date + 1, issue2.reload.start_date
  end

  def test_rescheduling_a_stale_issue_should_not_raise_an_error
    stale = Issue.find(1)
    issue = Issue.find(1)
    issue.subject = "Updated"
    issue.save!

    date = 10.days.from_now.to_date
    assert_nothing_raised do
      stale.reschedule_after(date)
    end
    assert_equal date, stale.reload.start_date
  end

  def test_overdue
    assert Issue.new(:due_date => 1.day.ago.to_date).overdue?
    assert !Issue.new(:due_date => Date.today).overdue?
    assert !Issue.new(:due_date => 1.day.from_now.to_date).overdue?
    assert !Issue.new(:due_date => nil).overdue?
    assert !Issue.new(:due_date => 1.day.ago.to_date, :status => IssueStatus.find(:first, :conditions => {:is_closed => true})).overdue?
  end

  context "#behind_schedule?" do
    should "be false if the issue has no start_date" do
      assert !Issue.new(:start_date => nil, :due_date => 1.day.from_now.to_date, :done_ratio => 0).behind_schedule?
    end

    should "be false if the issue has no end_date" do
      assert !Issue.new(:start_date => 1.day.from_now.to_date, :due_date => nil, :done_ratio => 0).behind_schedule?
    end

    should "be false if the issue has more done than it's calendar time" do
      assert !Issue.new(:start_date => 50.days.ago.to_date, :due_date => 50.days.from_now.to_date, :done_ratio => 90).behind_schedule?
    end

    should "be true if the issue hasn't been started at all" do
      assert Issue.new(:start_date => 1.day.ago.to_date, :due_date => 1.day.from_now.to_date, :done_ratio => 0).behind_schedule?
    end

    should "be true if the issue has used more calendar time than it's done ratio" do
      assert Issue.new(:start_date => 100.days.ago.to_date, :due_date => Date.today, :done_ratio => 90).behind_schedule?
    end
  end

  context "#assignable_users" do
    should "be Users" do
      assert_kind_of User, Issue.find(1).assignable_users.first
    end

    should "include the issue author" do
      project = Project.find(1)
      non_project_member = User.generate!
      issue = Issue.generate_for_project!(project, :author => non_project_member)

      assert issue.assignable_users.include?(non_project_member)
    end

    should "include the current assignee" do
      project = Project.find(1)
      user = User.generate!
      issue = Issue.generate_for_project!(project, :assigned_to => user)
      user.lock!

      assert Issue.find(issue.id).assignable_users.include?(user)
    end

    should "not show the issue author twice" do
      assignable_user_ids = Issue.find(1).assignable_users.collect(&:id)
      assert_equal 2, assignable_user_ids.length

      assignable_user_ids.each do |user_id|
        assert_equal 1, assignable_user_ids.select {|i| i == user_id}.length, "User #{user_id} appears more or less than once"
      end
    end

    context "with issue_group_assignment" do
      should "include groups" do
        issue = Issue.new(:project => Project.find(2))

        with_settings :issue_group_assignment => '1' do
          assert_equal %w(Group User), issue.assignable_users.map {|a| a.class.name}.uniq.sort
          assert issue.assignable_users.include?(Group.find(11))
        end
      end
    end

    context "without issue_group_assignment" do
      should "not include groups" do
        issue = Issue.new(:project => Project.find(2))

        with_settings :issue_group_assignment => '0' do
          assert_equal %w(User), issue.assignable_users.map {|a| a.class.name}.uniq.sort
          assert !issue.assignable_users.include?(Group.find(11))
        end
      end
    end
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 3, :status_id => 1,
                      :priority => IssuePriority.all.first,
                      :subject => 'test_create', :estimated_hours => '1:30')

    assert issue.save
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_stale_issue_should_not_send_email_notification
    ActionMailer::Base.deliveries.clear
    issue = Issue.find(1)
    stale = Issue.find(1)

    issue.init_journal(User.find(1))
    issue.subject = 'Subjet update'
    assert issue.save
    assert_equal 1, ActionMailer::Base.deliveries.size
    ActionMailer::Base.deliveries.clear

    stale.init_journal(User.find(1))
    stale.subject = 'Another subjet update'
    assert_raise ActiveRecord::StaleObjectError do
      stale.save
    end
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_journalized_description
    IssueCustomField.delete_all

    i = Issue.first
    old_description = i.description
    new_description = "This is the new description"

    i.init_journal(User.find(2))
    i.description = new_description
    assert_difference 'Journal.count', 1 do
      assert_difference 'JournalDetail.count', 1 do
        i.save!
      end
    end

    detail = JournalDetail.first(:order => 'id DESC')
    assert_equal i, detail.journal.journalized
    assert_equal 'attr', detail.property
    assert_equal 'description', detail.prop_key
    assert_equal old_description, detail.old_value
    assert_equal new_description, detail.value
  end

  def test_blank_descriptions_should_not_be_journalized
    IssueCustomField.delete_all
    Issue.update_all("description = NULL", "id=1")

    i = Issue.find(1)
    i.init_journal(User.find(2))
    i.subject = "blank description"
    i.description = "\r\n"

    assert_difference 'Journal.count', 1 do
      assert_difference 'JournalDetail.count', 1 do
        i.save!
      end
    end
  end

  def test_journalized_multi_custom_field
    field = IssueCustomField.create!(:name => 'filter', :field_format => 'list', :is_filter => true, :is_for_all => true,
      :tracker_ids => [1], :possible_values => ['value1', 'value2', 'value3'], :multiple => true)

    issue = Issue.create!(:project_id => 1, :tracker_id => 1, :subject => 'Test', :author_id => 1)

    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => ['value1']}
        issue.save!
      end
      assert_difference 'JournalDetail.count' do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => ['value1', 'value2']}
        issue.save!
      end
      assert_difference 'JournalDetail.count', 2 do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => ['value3', 'value2']}
        issue.save!
      end
      assert_difference 'JournalDetail.count', 2 do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => nil}
        issue.save!
      end
    end
  end

  def test_description_eol_should_be_normalized
    i = Issue.new(:description => "CR \r LF \n CRLF \r\n")
    assert_equal "CR \r\n LF \r\n CRLF \r\n", i.description
  end

  def test_saving_twice_should_not_duplicate_journal_details
    i = Issue.find(:first)
    i.init_journal(User.find(2), 'Some notes')
    # initial changes
    i.subject = 'New subject'
    i.done_ratio = i.done_ratio + 10
    assert_difference 'Journal.count' do
      assert i.save
    end
    # 1 more change
    i.priority = IssuePriority.find(:first, :conditions => ["id <> ?", i.priority_id])
    assert_no_difference 'Journal.count' do
      assert_difference 'JournalDetail.count', 1 do
        i.save
      end
    end
    # no more change
    assert_no_difference 'Journal.count' do
      assert_no_difference 'JournalDetail.count' do
        i.save
      end
    end
  end

  def test_all_dependent_issues
    IssueRelation.delete_all
    assert IssueRelation.create!(:issue_from => Issue.find(1),
                                 :issue_to   => Issue.find(2),
                                 :relation_type => IssueRelation::TYPE_PRECEDES)
    assert IssueRelation.create!(:issue_from => Issue.find(2),
                                 :issue_to   => Issue.find(3),
                                 :relation_type => IssueRelation::TYPE_PRECEDES)
    assert IssueRelation.create!(:issue_from => Issue.find(3),
                                 :issue_to   => Issue.find(8),
                                 :relation_type => IssueRelation::TYPE_PRECEDES)

    assert_equal [2, 3, 8], Issue.find(1).all_dependent_issues.collect(&:id).sort
  end

  def test_all_dependent_issues_with_persistent_circular_dependency
    IssueRelation.delete_all
    assert IssueRelation.create!(:issue_from => Issue.find(1),
                                 :issue_to   => Issue.find(2),
                                 :relation_type => IssueRelation::TYPE_PRECEDES)
    assert IssueRelation.create!(:issue_from => Issue.find(2),
                                 :issue_to   => Issue.find(3),
                                 :relation_type => IssueRelation::TYPE_PRECEDES)

    r = IssueRelation.create!(:issue_from => Issue.find(3),
                             :issue_to   => Issue.find(7),
                             :relation_type => IssueRelation::TYPE_PRECEDES)
    IssueRelation.update_all("issue_to_id = 1", ["id = ?", r.id])
    
    assert_equal [2, 3], Issue.find(1).all_dependent_issues.collect(&:id).sort
  end

  def test_all_dependent_issues_with_persistent_multiple_circular_dependencies
    IssueRelation.delete_all
    assert IssueRelation.create!(:issue_from => Issue.find(1),
                                 :issue_to   => Issue.find(2),
                                 :relation_type => IssueRelation::TYPE_RELATES)
    assert IssueRelation.create!(:issue_from => Issue.find(2),
                                 :issue_to   => Issue.find(3),
                                 :relation_type => IssueRelation::TYPE_RELATES)
    assert IssueRelation.create!(:issue_from => Issue.find(3),
                                 :issue_to   => Issue.find(8),
                                 :relation_type => IssueRelation::TYPE_RELATES)

    r = IssueRelation.create!(:issue_from => Issue.find(8),
                             :issue_to   => Issue.find(7),
                             :relation_type => IssueRelation::TYPE_RELATES)
    IssueRelation.update_all("issue_to_id = 2", ["id = ?", r.id])
    
    r = IssueRelation.create!(:issue_from => Issue.find(3),
                             :issue_to   => Issue.find(7),
                             :relation_type => IssueRelation::TYPE_RELATES)
    IssueRelation.update_all("issue_to_id = 1", ["id = ?", r.id])

    assert_equal [2, 3, 8], Issue.find(1).all_dependent_issues.collect(&:id).sort
  end

  context "#done_ratio" do
    setup do
      @issue = Issue.find(1)
      @issue_status = IssueStatus.find(1)
      @issue_status.update_attribute(:default_done_ratio, 50)
      @issue2 = Issue.find(2)
      @issue_status2 = IssueStatus.find(2)
      @issue_status2.update_attribute(:default_done_ratio, 0)
    end

    teardown do
      Setting.issue_done_ratio = 'issue_field'
    end

    context "with Setting.issue_done_ratio using the issue_field" do
      setup do
        Setting.issue_done_ratio = 'issue_field'
      end

      should "read the issue's field" do
        assert_equal 0, @issue.done_ratio
        assert_equal 30, @issue2.done_ratio
      end
    end

    context "with Setting.issue_done_ratio using the issue_status" do
      setup do
        Setting.issue_done_ratio = 'issue_status'
      end

      should "read the Issue Status's default done ratio" do
        assert_equal 50, @issue.done_ratio
        assert_equal 0, @issue2.done_ratio
      end
    end
  end

  context "#update_done_ratio_from_issue_status" do
    setup do
      @issue = Issue.find(1)
      @issue_status = IssueStatus.find(1)
      @issue_status.update_attribute(:default_done_ratio, 50)
      @issue2 = Issue.find(2)
      @issue_status2 = IssueStatus.find(2)
      @issue_status2.update_attribute(:default_done_ratio, 0)
    end

    context "with Setting.issue_done_ratio using the issue_field" do
      setup do
        Setting.issue_done_ratio = 'issue_field'
      end

      should "not change the issue" do
        @issue.update_done_ratio_from_issue_status
        @issue2.update_done_ratio_from_issue_status

        assert_equal 0, @issue.read_attribute(:done_ratio)
        assert_equal 30, @issue2.read_attribute(:done_ratio)
      end
    end

    context "with Setting.issue_done_ratio using the issue_status" do
      setup do
        Setting.issue_done_ratio = 'issue_status'
      end

      should "change the issue's done ratio" do
        @issue.update_done_ratio_from_issue_status
        @issue2.update_done_ratio_from_issue_status

        assert_equal 50, @issue.read_attribute(:done_ratio)
        assert_equal 0, @issue2.read_attribute(:done_ratio)
      end
    end
  end

  test "#by_tracker" do
    User.current = User.anonymous
    groups = Issue.by_tracker(Project.find(1))
    assert_equal 3, groups.size
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_version" do
    User.current = User.anonymous
    groups = Issue.by_version(Project.find(1))
    assert_equal 3, groups.size
    assert_equal 3, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_priority" do
    User.current = User.anonymous
    groups = Issue.by_priority(Project.find(1))
    assert_equal 4, groups.size
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_category" do
    User.current = User.anonymous
    groups = Issue.by_category(Project.find(1))
    assert_equal 2, groups.size
    assert_equal 3, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_assigned_to" do
    User.current = User.anonymous
    groups = Issue.by_assigned_to(Project.find(1))
    assert_equal 2, groups.size
    assert_equal 2, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_author" do
    User.current = User.anonymous
    groups = Issue.by_author(Project.find(1))
    assert_equal 4, groups.size
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_subproject" do
    User.current = User.anonymous
    groups = Issue.by_subproject(Project.find(1))
    # Private descendant not visible
    assert_equal 1, groups.size
    assert_equal 2, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  def test_recently_updated_scope
    #should return the last updated issue
    assert_equal Issue.reorder("updated_on DESC").first, Issue.recently_updated.limit(1).first
  end

  def test_on_active_projects_scope
    assert Project.find(2).archive

    before = Issue.on_active_project.length
    # test inclusion to results
    issue = Issue.generate_for_project!(Project.find(1), :tracker => Project.find(2).trackers.first)
    assert_equal before + 1, Issue.on_active_project.length

    # Move to an archived project
    issue.project = Project.find(2)
    assert issue.save
    assert_equal before, Issue.on_active_project.length
  end

  context "Issue#recipients" do
    setup do
      @project = Project.find(1)
      @author = User.generate!
      @assignee = User.generate!
      @issue = Issue.generate_for_project!(@project, :assigned_to => @assignee, :author => @author)
    end

    should "include project recipients" do
      assert @project.recipients.present?
      @project.recipients.each do |project_recipient|
        assert @issue.recipients.include?(project_recipient)
      end
    end

    should "include the author if the author is active" do
      assert @issue.author, "No author set for Issue"
      assert @issue.recipients.include?(@issue.author.mail)
    end

    should "include the assigned to user if the assigned to user is active" do
      assert @issue.assigned_to, "No assigned_to set for Issue"
      assert @issue.recipients.include?(@issue.assigned_to.mail)
    end

    should "not include users who opt out of all email" do
      @author.update_attribute(:mail_notification, :none)

      assert !@issue.recipients.include?(@issue.author.mail)
    end

    should "not include the issue author if they are only notified of assigned issues" do
      @author.update_attribute(:mail_notification, :only_assigned)

      assert !@issue.recipients.include?(@issue.author.mail)
    end

    should "not include the assigned user if they are only notified of owned issues" do
      @assignee.update_attribute(:mail_notification, :only_owner)

      assert !@issue.recipients.include?(@issue.assigned_to.mail)
    end
  end

  def test_last_journal_id_with_journals_should_return_the_journal_id
    assert_equal 2, Issue.find(1).last_journal_id
  end

  def test_last_journal_id_without_journals_should_return_nil
    assert_nil Issue.find(3).last_journal_id
  end

  def test_journals_after_should_return_journals_with_greater_id
    assert_equal [Journal.find(2)], Issue.find(1).journals_after('1')
    assert_equal [], Issue.find(1).journals_after('2')
  end

  def test_journals_after_with_blank_arg_should_return_all_journals
    assert_equal [Journal.find(1), Journal.find(2)], Issue.find(1).journals_after('')
  end

  def test_save_attachments_with_hash_should_save_attachments_in_keys_order
    set_tmp_attachments_directory
    issue = Issue.generate!
    issue.save_attachments({
      'p0' => {'file' => mock_file_with_options(:original_filename => 'upload')},
      '3' => {'file' => mock_file_with_options(:original_filename => 'bar')},
      '1' => {'file' => mock_file_with_options(:original_filename => 'foo')}
    })
    issue.attach_saved_attachments

    assert_equal 3, issue.reload.attachments.count
    assert_equal %w(upload foo bar), issue.attachments.map(&:filename)
  end
end
