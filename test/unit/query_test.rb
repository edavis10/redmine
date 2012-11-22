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

class QueryTest < ActiveSupport::TestCase
  include Redmine::I18n

  fixtures :projects, :enabled_modules, :users, :members,
           :member_roles, :roles, :trackers, :issue_statuses,
           :issue_categories, :enumerations, :issues,
           :watchers, :custom_fields, :custom_values, :versions,
           :queries,
           :projects_trackers,
           :custom_fields_trackers

  def test_custom_fields_for_all_projects_should_be_available_in_global_queries
    query = Query.new(:project => nil, :name => '_')
    assert query.available_filters.has_key?('cf_1')
    assert !query.available_filters.has_key?('cf_3')
  end

  def test_system_shared_versions_should_be_available_in_global_queries
    Version.find(2).update_attribute :sharing, 'system'
    query = Query.new(:project => nil, :name => '_')
    assert query.available_filters.has_key?('fixed_version_id')
    assert query.available_filters['fixed_version_id'][:values].detect {|v| v.last == '2'}
  end

  def test_project_filter_in_global_queries
    query = Query.new(:project => nil, :name => '_')
    project_filter = query.available_filters["project_id"]
    assert_not_nil project_filter
    project_ids = project_filter[:values].map{|p| p[1]}
    assert project_ids.include?("1")  #public project
    assert !project_ids.include?("2") #private project user cannot see
  end

  def find_issues_with_query(query)
    Issue.includes([:assigned_to, :status, :tracker, :project, :priority]).where(
         query.statement
       ).all
  end

  def assert_find_issues_with_query_is_successful(query)
    assert_nothing_raised do
      find_issues_with_query(query)
    end
  end

  def assert_query_statement_includes(query, condition)
    assert query.statement.include?(condition), "Query statement condition not found in: #{query.statement}"
  end
  
  def assert_query_result(expected, query)
    assert_nothing_raised do
      assert_equal expected.map(&:id).sort, query.issues.map(&:id).sort
      assert_equal expected.size, query.issue_count
    end
  end

  def test_query_should_allow_shared_versions_for_a_project_query
    subproject_version = Version.find(4)
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('fixed_version_id', '=', [subproject_version.id.to_s])

    assert query.statement.include?("#{Issue.table_name}.fixed_version_id IN ('4')")
  end

  def test_query_with_multiple_custom_fields
    query = Query.find(1)
    assert query.valid?
    assert query.statement.include?("#{CustomValue.table_name}.value IN ('MySQL')")
    issues = find_issues_with_query(query)
    assert_equal 1, issues.length
    assert_equal Issue.find(3), issues.first
  end

  def test_operator_none
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('fixed_version_id', '!*', [''])
    query.add_filter('cf_1', '!*', [''])
    assert query.statement.include?("#{Issue.table_name}.fixed_version_id IS NULL")
    assert query.statement.include?("#{CustomValue.table_name}.value IS NULL OR #{CustomValue.table_name}.value = ''")
    find_issues_with_query(query)
  end

  def test_operator_none_for_integer
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('estimated_hours', '!*', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| !i.estimated_hours}
  end

  def test_operator_none_for_date
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('start_date', '!*', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.start_date.nil?}
  end

  def test_operator_none_for_string_custom_field
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('cf_2', '!*', [''])
    assert query.has_filter?('cf_2')
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.custom_field_value(2).blank?}
  end

  def test_operator_all
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('fixed_version_id', '*', [''])
    query.add_filter('cf_1', '*', [''])
    assert query.statement.include?("#{Issue.table_name}.fixed_version_id IS NOT NULL")
    assert query.statement.include?("#{CustomValue.table_name}.value IS NOT NULL AND #{CustomValue.table_name}.value <> ''")
    find_issues_with_query(query)
  end

  def test_operator_all_for_date
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('start_date', '*', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.start_date.present?}
  end

  def test_operator_all_for_string_custom_field
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('cf_2', '*', [''])
    assert query.has_filter?('cf_2')
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.custom_field_value(2).present?}
  end

  def test_numeric_filter_should_not_accept_non_numeric_values
    query = Query.new(:name => '_')
    query.add_filter('estimated_hours', '=', ['a'])

    assert query.has_filter?('estimated_hours')
    assert !query.valid?
  end

  def test_operator_is_on_float
    Issue.update_all("estimated_hours = 171.2", "id=2")

    query = Query.new(:name => '_')
    query.add_filter('estimated_hours', '=', ['171.20'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_integer_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_for_all => true, :is_filter => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '12')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['12'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_integer_custom_field_should_accept_negative_value
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_for_all => true, :is_filter => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '-12')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['-12'])
    assert query.valid?
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_float_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'float', :is_filter => true, :is_for_all => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7.3')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '12.7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['12.7'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_float_custom_field_should_accept_negative_value
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'float', :is_filter => true, :is_for_all => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7.3')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '-12.7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['-12.7'])
    assert query.valid?
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_multi_list_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'list', :is_filter => true, :is_for_all => true,
      :possible_values => ['value1', 'value2', 'value3'], :multiple => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value1')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value2')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => 'value1')

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['value1'])
    issues = find_issues_with_query(query)
    assert_equal [1, 3], issues.map(&:id).sort

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['value2'])
    issues = find_issues_with_query(query)
    assert_equal [1], issues.map(&:id).sort
  end

  def test_operator_is_not_on_multi_list_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'list', :is_filter => true, :is_for_all => true,
      :possible_values => ['value1', 'value2', 'value3'], :multiple => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value1')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value2')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => 'value1')

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '!', ['value1'])
    issues = find_issues_with_query(query)
    assert !issues.map(&:id).include?(1)
    assert !issues.map(&:id).include?(3)

    query = Query.new(:name => '_')
    query.add_filter("cf_#{f.id}", '!', ['value2'])
    issues = find_issues_with_query(query)
    assert !issues.map(&:id).include?(1)
    assert issues.map(&:id).include?(3)
  end

  def test_operator_is_on_is_private_field
    # is_private filter only available for those who can set issues private
    User.current = User.find(2)

    query = Query.new(:name => '_')
    assert query.available_filters.key?('is_private')

    query.add_filter("is_private", '=', ['1'])
    issues = find_issues_with_query(query)
    assert issues.any?
    assert_nil issues.detect {|issue| !issue.is_private?}
  ensure
    User.current = nil
  end

  def test_operator_is_not_on_is_private_field
    # is_private filter only available for those who can set issues private
    User.current = User.find(2)

    query = Query.new(:name => '_')
    assert query.available_filters.key?('is_private')

    query.add_filter("is_private", '!', ['1'])
    issues = find_issues_with_query(query)
    assert issues.any?
    assert_nil issues.detect {|issue| issue.is_private?}
  ensure
    User.current = nil
  end

  def test_operator_greater_than
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('done_ratio', '>=', ['40'])
    assert query.statement.include?("#{Issue.table_name}.done_ratio >= 40.0")
    find_issues_with_query(query)
  end

  def test_operator_greater_than_a_float
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('estimated_hours', '>=', ['40.5'])
    assert query.statement.include?("#{Issue.table_name}.estimated_hours >= 40.5")
    find_issues_with_query(query)
  end

  def test_operator_greater_than_on_int_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_filter => true, :is_for_all => true)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '12')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '>=', ['8'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_lesser_than
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('done_ratio', '<=', ['30'])
    assert query.statement.include?("#{Issue.table_name}.done_ratio <= 30.0")
    find_issues_with_query(query)
  end

  def test_operator_lesser_than_on_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_filter => true, :is_for_all => true)
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '<=', ['30'])
    assert query.statement.include?("CAST(custom_values.value AS decimal(60,3)) <= 30.0")
    find_issues_with_query(query)
  end

  def test_operator_between
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('done_ratio', '><', ['30', '40'])
    assert_include "#{Issue.table_name}.done_ratio BETWEEN 30.0 AND 40.0", query.statement
    find_issues_with_query(query)
  end

  def test_operator_between_on_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_filter => true, :is_for_all => true)
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '><', ['30', '40'])
    assert_include "CAST(custom_values.value AS decimal(60,3)) BETWEEN 30.0 AND 40.0", query.statement
    find_issues_with_query(query)
  end

  def test_date_filter_should_not_accept_non_date_values
    query = Query.new(:name => '_')
    query.add_filter('created_on', '=', ['a'])

    assert query.has_filter?('created_on')
    assert !query.valid?
  end

  def test_date_filter_should_not_accept_invalid_date_values
    query = Query.new(:name => '_')
    query.add_filter('created_on', '=', ['2011-01-34'])

    assert query.has_filter?('created_on')
    assert !query.valid?
  end

  def test_relative_date_filter_should_not_accept_non_integer_values
    query = Query.new(:name => '_')
    query.add_filter('created_on', '>t-', ['a'])

    assert query.has_filter?('created_on')
    assert !query.valid?
  end

  def test_operator_date_equals
    query = Query.new(:name => '_')
    query.add_filter('due_date', '=', ['2011-07-10'])
    assert_match /issues\.due_date > '2011-07-09 23:59:59(\.9+)?' AND issues\.due_date <= '2011-07-10 23:59:59(\.9+)?/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_lesser_than
    query = Query.new(:name => '_')
    query.add_filter('due_date', '<=', ['2011-07-10'])
    assert_match /issues\.due_date <= '2011-07-10 23:59:59(\.9+)?/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_greater_than
    query = Query.new(:name => '_')
    query.add_filter('due_date', '>=', ['2011-07-10'])
    assert_match /issues\.due_date > '2011-07-09 23:59:59(\.9+)?'/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_between
    query = Query.new(:name => '_')
    query.add_filter('due_date', '><', ['2011-06-23', '2011-07-10'])
    assert_match /issues\.due_date > '2011-06-22 23:59:59(\.9+)?' AND issues\.due_date <= '2011-07-10 23:59:59(\.9+)?/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_in_more_than
    Issue.find(7).update_attribute(:due_date, (Date.today + 15))
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '>t+', ['15'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= (Date.today + 15))}
  end

  def test_operator_in_less_than
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '<t+', ['15'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= Date.today && issue.due_date <= (Date.today + 15))}
  end

  def test_operator_less_than_ago
    Issue.find(7).update_attribute(:due_date, (Date.today - 3))
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '>t-', ['3'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= (Date.today - 3) && issue.due_date <= Date.today)}
  end

  def test_operator_more_than_ago
    Issue.find(7).update_attribute(:due_date, (Date.today - 10))
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '<t-', ['10'])
    assert query.statement.include?("#{Issue.table_name}.due_date <=")
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date <= (Date.today - 10))}
  end

  def test_operator_in
    Issue.find(7).update_attribute(:due_date, (Date.today + 2))
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 't+', ['2'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert_equal((Date.today + 2), issue.due_date)}
  end

  def test_operator_ago
    Issue.find(7).update_attribute(:due_date, (Date.today - 3))
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 't-', ['3'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert_equal((Date.today - 3), issue.due_date)}
  end

  def test_operator_today
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 't', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert_equal Date.today, issue.due_date}
  end

  def test_operator_this_week_on_date
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 'w', [''])
    find_issues_with_query(query)
  end

  def test_operator_this_week_on_datetime
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('created_on', 'w', [''])
    find_issues_with_query(query)
  end

  def test_operator_contains
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('subject', '~', ['uNable'])
    assert query.statement.include?("LOWER(#{Issue.table_name}.subject) LIKE '%unable%'")
    result = find_issues_with_query(query)
    assert result.empty?
    result.each {|issue| assert issue.subject.downcase.include?('unable') }
  end

  def test_range_for_this_week_with_week_starting_on_monday
    I18n.locale = :fr
    assert_equal '1', I18n.t(:general_first_day_of_week)

    Date.stubs(:today).returns(Date.parse('2011-04-29'))

    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 'w', [''])
    assert query.statement.match(/issues\.due_date > '2011-04-24 23:59:59(\.9+)?' AND issues\.due_date <= '2011-05-01 23:59:59(\.9+)?/), "range not found in #{query.statement}"
    I18n.locale = :en
  end

  def test_range_for_this_week_with_week_starting_on_sunday
    I18n.locale = :en
    assert_equal '7', I18n.t(:general_first_day_of_week)

    Date.stubs(:today).returns(Date.parse('2011-04-29'))

    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 'w', [''])
    assert query.statement.match(/issues\.due_date > '2011-04-23 23:59:59(\.9+)?' AND issues\.due_date <= '2011-04-30 23:59:59(\.9+)?/), "range not found in #{query.statement}"
  end

  def test_operator_does_not_contains
    query = Query.new(:project => Project.find(1), :name => '_')
    query.add_filter('subject', '!~', ['uNable'])
    assert query.statement.include?("LOWER(#{Issue.table_name}.subject) NOT LIKE '%unable%'")
    find_issues_with_query(query)
  end

  def test_filter_assigned_to_me
    user = User.find(2)
    group = Group.find(10)
    User.current = user
    i1 = Issue.generate!(:project_id => 1, :tracker_id => 1, :assigned_to => user)
    i2 = Issue.generate!(:project_id => 1, :tracker_id => 1, :assigned_to => group)
    i3 = Issue.generate!(:project_id => 1, :tracker_id => 1, :assigned_to => Group.find(11))
    group.users << user

    query = Query.new(:name => '_', :filters => { 'assigned_to_id' => {:operator => '=', :values => ['me']}})
    result = query.issues
    assert_equal Issue.visible.all(:conditions => {:assigned_to_id => ([2] + user.reload.group_ids)}).sort_by(&:id), result.sort_by(&:id)

    assert result.include?(i1)
    assert result.include?(i2)
    assert !result.include?(i3)
  end

  def test_user_custom_field_filtered_on_me
    User.current = User.find(2)
    cf = IssueCustomField.create!(:field_format => 'user', :is_for_all => true, :is_filter => true, :name => 'User custom field', :tracker_ids => [1])
    issue1 = Issue.create!(:project_id => 1, :tracker_id => 1, :custom_field_values => {cf.id.to_s => '2'}, :subject => 'Test', :author_id => 1)
    issue2 = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {cf.id.to_s => '3'})

    query = Query.new(:name => '_', :project => Project.find(1))
    filter = query.available_filters["cf_#{cf.id}"]
    assert_not_nil filter
    assert_include 'me', filter[:values].map{|v| v[1]}

    query.filters = { "cf_#{cf.id}" => {:operator => '=', :values => ['me']}}
    result = query.issues
    assert_equal 1, result.size
    assert_equal issue1, result.first
  end

  def test_filter_my_projects
    User.current = User.find(2)
    query = Query.new(:name => '_')
    filter = query.available_filters['project_id']
    assert_not_nil filter
    assert_include 'mine', filter[:values].map{|v| v[1]}

    query.filters = { 'project_id' => {:operator => '=', :values => ['mine']}}
    result = query.issues
    assert_nil result.detect {|issue| !User.current.member_of?(issue.project)}
  end

  def test_filter_watched_issues
    User.current = User.find(1)
    query = Query.new(:name => '_', :filters => { 'watcher_id' => {:operator => '=', :values => ['me']}})
    result = find_issues_with_query(query)
    assert_not_nil result
    assert !result.empty?
    assert_equal Issue.visible.watched_by(User.current).sort_by(&:id), result.sort_by(&:id)
    User.current = nil
  end

  def test_filter_unwatched_issues
    User.current = User.find(1)
    query = Query.new(:name => '_', :filters => { 'watcher_id' => {:operator => '!', :values => ['me']}})
    result = find_issues_with_query(query)
    assert_not_nil result
    assert !result.empty?
    assert_equal((Issue.visible - Issue.watched_by(User.current)).sort_by(&:id).size, result.sort_by(&:id).size)
    User.current = nil
  end

  def test_filter_on_project_custom_field
    field = ProjectCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => Project.find(3), :value => 'Foo')
    CustomValue.create!(:custom_field => field, :customized => Project.find(5), :value => 'Foo')

    query = Query.new(:name => '_')
    filter_name = "project.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [3, 5], find_issues_with_query(query).map(&:project_id).uniq.sort
  end

  def test_filter_on_author_custom_field
    field = UserCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => User.find(3), :value => 'Foo')

    query = Query.new(:name => '_')
    filter_name = "author.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [3], find_issues_with_query(query).map(&:author_id).uniq.sort
  end

  def test_filter_on_assigned_to_custom_field
    field = UserCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => User.find(3), :value => 'Foo')

    query = Query.new(:name => '_')
    filter_name = "assigned_to.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [3], find_issues_with_query(query).map(&:assigned_to_id).uniq.sort
  end

  def test_filter_on_fixed_version_custom_field
    field = VersionCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => Version.find(2), :value => 'Foo')

    query = Query.new(:name => '_')
    filter_name = "fixed_version.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [2], find_issues_with_query(query).map(&:fixed_version_id).uniq.sort
  end

  def test_statement_should_be_nil_with_no_filters
    q = Query.new(:name => '_')
    q.filters = {}

    assert q.valid?
    assert_nil q.statement
  end

  def test_default_columns
    q = Query.new
    assert !q.columns.empty?
  end

  def test_set_column_names
    q = Query.new
    q.column_names = ['tracker', :subject, '', 'unknonw_column']
    assert_equal [:tracker, :subject], q.columns.collect {|c| c.name}
    c = q.columns.first
    assert q.has_column?(c)
  end

  def test_query_should_preload_spent_hours
    q = Query.new(:name => '_', :column_names => [:subject, :spent_hours])
    assert q.has_column?(:spent_hours)
    issues = q.issues
    assert_not_nil issues.first.instance_variable_get("@spent_hours")
  end

  def test_groupable_columns_should_include_custom_fields
    q = Query.new
    column = q.groupable_columns.detect {|c| c.name == :cf_1}
    assert_not_nil column
    assert_kind_of QueryCustomFieldColumn, column
  end

  def test_groupable_columns_should_not_include_multi_custom_fields
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    q = Query.new
    column = q.groupable_columns.detect {|c| c.name == :cf_1}
    assert_nil column
  end

  def test_groupable_columns_should_include_user_custom_fields
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1], :field_format => 'user')

    q = Query.new
    assert q.groupable_columns.detect {|c| c.name == "cf_#{cf.id}".to_sym}
  end

  def test_groupable_columns_should_include_version_custom_fields
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1], :field_format => 'version')

    q = Query.new
    assert q.groupable_columns.detect {|c| c.name == "cf_#{cf.id}".to_sym}
  end

  def test_grouped_with_valid_column
    q = Query.new(:group_by => 'status')
    assert q.grouped?
    assert_not_nil q.group_by_column
    assert_equal :status, q.group_by_column.name
    assert_not_nil q.group_by_statement
    assert_equal 'status', q.group_by_statement
  end

  def test_grouped_with_invalid_column
    q = Query.new(:group_by => 'foo')
    assert !q.grouped?
    assert_nil q.group_by_column
    assert_nil q.group_by_statement
  end
  
  def test_sortable_columns_should_sort_assignees_according_to_user_format_setting
    with_settings :user_format => 'lastname_coma_firstname' do
      q = Query.new
      assert q.sortable_columns.has_key?('assigned_to')
      assert_equal %w(users.lastname users.firstname users.id), q.sortable_columns['assigned_to']
    end
  end
  
  def test_sortable_columns_should_sort_authors_according_to_user_format_setting
    with_settings :user_format => 'lastname_coma_firstname' do
      q = Query.new
      assert q.sortable_columns.has_key?('author')
      assert_equal %w(authors.lastname authors.firstname authors.id), q.sortable_columns['author']
    end
  end

  def test_sortable_columns_should_include_custom_field
    q = Query.new
    assert q.sortable_columns['cf_1']
  end

  def test_sortable_columns_should_not_include_multi_custom_field
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    q = Query.new
    assert !q.sortable_columns['cf_1']
  end

  def test_default_sort
    q = Query.new
    assert_equal [], q.sort_criteria
  end

  def test_set_sort_criteria_with_hash
    q = Query.new
    q.sort_criteria = {'0' => ['priority', 'desc'], '2' => ['tracker']}
    assert_equal [['priority', 'desc'], ['tracker', 'asc']], q.sort_criteria
  end

  def test_set_sort_criteria_with_array
    q = Query.new
    q.sort_criteria = [['priority', 'desc'], 'tracker']
    assert_equal [['priority', 'desc'], ['tracker', 'asc']], q.sort_criteria
  end

  def test_create_query_with_sort
    q = Query.new(:name => 'Sorted')
    q.sort_criteria = [['priority', 'desc'], 'tracker']
    assert q.save
    q.reload
    assert_equal [['priority', 'desc'], ['tracker', 'asc']], q.sort_criteria
  end

  def test_sort_by_string_custom_field_asc
    q = Query.new
    c = q.available_columns.find {|col| col.is_a?(QueryCustomFieldColumn) && col.custom_field.field_format == 'string' }
    assert c
    assert c.sortable
    issues = Issue.includes([:assigned_to, :status, :tracker, :project, :priority]).where(
         q.statement
       ).order("#{c.sortable} ASC").all
    values = issues.collect {|i| i.custom_value_for(c.custom_field).to_s}
    assert !values.empty?
    assert_equal values.sort, values
  end

  def test_sort_by_string_custom_field_desc
    q = Query.new
    c = q.available_columns.find {|col| col.is_a?(QueryCustomFieldColumn) && col.custom_field.field_format == 'string' }
    assert c
    assert c.sortable
    issues = Issue.includes([:assigned_to, :status, :tracker, :project, :priority]).where(
         q.statement
       ).order("#{c.sortable} DESC").all
    values = issues.collect {|i| i.custom_value_for(c.custom_field).to_s}
    assert !values.empty?
    assert_equal values.sort.reverse, values
  end

  def test_sort_by_float_custom_field_asc
    q = Query.new
    c = q.available_columns.find {|col| col.is_a?(QueryCustomFieldColumn) && col.custom_field.field_format == 'float' }
    assert c
    assert c.sortable
    issues = Issue.includes([:assigned_to, :status, :tracker, :project, :priority]).where(
         q.statement
       ).order("#{c.sortable} ASC").all
    values = issues.collect {|i| begin; Kernel.Float(i.custom_value_for(c.custom_field).to_s); rescue; nil; end}.compact
    assert !values.empty?
    assert_equal values.sort, values
  end

  def test_invalid_query_should_raise_query_statement_invalid_error
    q = Query.new
    assert_raise Query::StatementInvalid do
      q.issues(:conditions => "foo = 1")
    end
  end

  def test_issue_count
    q = Query.new(:name => '_')
    issue_count = q.issue_count
    assert_equal q.issues.size, issue_count
  end

  def test_issue_count_with_archived_issues
    p = Project.generate! do |project|
      project.status = Project::STATUS_ARCHIVED
    end
    i = Issue.generate!( :project => p, :tracker => p.trackers.first )
    assert !i.visible?

    test_issue_count
  end

  def test_issue_count_by_association_group
    q = Query.new(:name => '_', :group_by => 'assigned_to')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal %w(NilClass User), count_by_group.keys.collect {|k| k.class.name}.uniq.sort
    assert_equal %w(Fixnum), count_by_group.values.collect {|k| k.class.name}.uniq
    assert count_by_group.has_key?(User.find(3))
  end

  def test_issue_count_by_list_custom_field_group
    q = Query.new(:name => '_', :group_by => 'cf_1')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal %w(NilClass String), count_by_group.keys.collect {|k| k.class.name}.uniq.sort
    assert_equal %w(Fixnum), count_by_group.values.collect {|k| k.class.name}.uniq
    assert count_by_group.has_key?('MySQL')
  end

  def test_issue_count_by_date_custom_field_group
    q = Query.new(:name => '_', :group_by => 'cf_8')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal %w(Date NilClass), count_by_group.keys.collect {|k| k.class.name}.uniq.sort
    assert_equal %w(Fixnum), count_by_group.values.collect {|k| k.class.name}.uniq
  end

  def test_issue_count_with_nil_group_only
    Issue.update_all("assigned_to_id = NULL")

    q = Query.new(:name => '_', :group_by => 'assigned_to')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal 1, count_by_group.keys.size
    assert_nil count_by_group.keys.first
  end

  def test_issue_ids
    q = Query.new(:name => '_')
    order = "issues.subject, issues.id"
    issues = q.issues(:order => order)
    assert_equal issues.map(&:id), q.issue_ids(:order => order)
  end

  def test_label_for
    set_language_if_valid 'en'
    q = Query.new
    assert_equal 'Assignee', q.label_for('assigned_to_id')
  end

  def test_label_for_fr
    set_language_if_valid 'fr'
    q = Query.new
    s = "Assign\xc3\xa9 \xc3\xa0"
    s.force_encoding('UTF-8') if s.respond_to?(:force_encoding)
    assert_equal s, q.label_for('assigned_to_id')
  end

  def test_editable_by
    admin = User.find(1)
    manager = User.find(2)
    developer = User.find(3)

    # Public query on project 1
    q = Query.find(1)
    assert q.editable_by?(admin)
    assert q.editable_by?(manager)
    assert !q.editable_by?(developer)

    # Private query on project 1
    q = Query.find(2)
    assert q.editable_by?(admin)
    assert !q.editable_by?(manager)
    assert q.editable_by?(developer)

    # Private query for all projects
    q = Query.find(3)
    assert q.editable_by?(admin)
    assert !q.editable_by?(manager)
    assert q.editable_by?(developer)

    # Public query for all projects
    q = Query.find(4)
    assert q.editable_by?(admin)
    assert !q.editable_by?(manager)
    assert !q.editable_by?(developer)
  end

  def test_visible_scope
    query_ids = Query.visible(User.anonymous).map(&:id)

    assert query_ids.include?(1), 'public query on public project was not visible'
    assert query_ids.include?(4), 'public query for all projects was not visible'
    assert !query_ids.include?(2), 'private query on public project was visible'
    assert !query_ids.include?(3), 'private query for all projects was visible'
    assert !query_ids.include?(7), 'public query on private project was visible'
  end

  context "#available_filters" do
    setup do
      @query = Query.new(:name => "_")
    end

    should "include users of visible projects in cross-project view" do
      users = @query.available_filters["assigned_to_id"]
      assert_not_nil users
      assert users[:values].map{|u|u[1]}.include?("3")
    end

    should "include users of subprojects" do
      user1 = User.generate!
      user2 = User.generate!
      project = Project.find(1)
      Member.create!(:principal => user1, :project => project.children.visible.first, :role_ids => [1])
      @query.project = project

      users = @query.available_filters["assigned_to_id"]
      assert_not_nil users
      assert users[:values].map{|u|u[1]}.include?(user1.id.to_s)
      assert !users[:values].map{|u|u[1]}.include?(user2.id.to_s)
    end

    should "include visible projects in cross-project view" do
      projects = @query.available_filters["project_id"]
      assert_not_nil projects
      assert projects[:values].map{|u|u[1]}.include?("1")
    end

    context "'member_of_group' filter" do
      should "be present" do
        assert @query.available_filters.keys.include?("member_of_group")
      end

      should "be an optional list" do
        assert_equal :list_optional, @query.available_filters["member_of_group"][:type]
      end

      should "have a list of the groups as values" do
        Group.destroy_all # No fixtures
        group1 = Group.generate!.reload
        group2 = Group.generate!.reload

        expected_group_list = [
                               [group1.name, group1.id.to_s],
                               [group2.name, group2.id.to_s]
                              ]
        assert_equal expected_group_list.sort, @query.available_filters["member_of_group"][:values].sort
      end

    end

    context "'assigned_to_role' filter" do
      should "be present" do
        assert @query.available_filters.keys.include?("assigned_to_role")
      end

      should "be an optional list" do
        assert_equal :list_optional, @query.available_filters["assigned_to_role"][:type]
      end

      should "have a list of the Roles as values" do
        assert @query.available_filters["assigned_to_role"][:values].include?(['Manager','1'])
        assert @query.available_filters["assigned_to_role"][:values].include?(['Developer','2'])
        assert @query.available_filters["assigned_to_role"][:values].include?(['Reporter','3'])
      end

      should "not include the built in Roles as values" do
        assert ! @query.available_filters["assigned_to_role"][:values].include?(['Non member','4'])
        assert ! @query.available_filters["assigned_to_role"][:values].include?(['Anonymous','5'])
      end

    end

  end

  context "#statement" do
    context "with 'member_of_group' filter" do
      setup do
        Group.destroy_all # No fixtures
        @user_in_group = User.generate!
        @second_user_in_group = User.generate!
        @user_in_group2 = User.generate!
        @user_not_in_group = User.generate!

        @group = Group.generate!.reload
        @group.users << @user_in_group
        @group.users << @second_user_in_group

        @group2 = Group.generate!.reload
        @group2.users << @user_in_group2

      end

      should "search assigned to for users in the group" do
        @query = Query.new(:name => '_')
        @query.add_filter('member_of_group', '=', [@group.id.to_s])

        assert_query_statement_includes @query, "#{Issue.table_name}.assigned_to_id IN ('#{@user_in_group.id}','#{@second_user_in_group.id}')"
        assert_find_issues_with_query_is_successful @query
      end

      should "search not assigned to any group member (none)" do
        @query = Query.new(:name => '_')
        @query.add_filter('member_of_group', '!*', [''])

        # Users not in a group
        assert_query_statement_includes @query, "#{Issue.table_name}.assigned_to_id IS NULL OR #{Issue.table_name}.assigned_to_id NOT IN ('#{@user_in_group.id}','#{@second_user_in_group.id}','#{@user_in_group2.id}')"
        assert_find_issues_with_query_is_successful @query
      end

      should "search assigned to any group member (all)" do
        @query = Query.new(:name => '_')
        @query.add_filter('member_of_group', '*', [''])

        # Only users in a group
        assert_query_statement_includes @query, "#{Issue.table_name}.assigned_to_id IN ('#{@user_in_group.id}','#{@second_user_in_group.id}','#{@user_in_group2.id}')"
        assert_find_issues_with_query_is_successful @query
      end

      should "return an empty set with = empty group" do
        @empty_group = Group.generate!
        @query = Query.new(:name => '_')
        @query.add_filter('member_of_group', '=', [@empty_group.id.to_s])

        assert_equal [], find_issues_with_query(@query)
      end

      should "return issues with ! empty group" do
        @empty_group = Group.generate!
        @query = Query.new(:name => '_')
        @query.add_filter('member_of_group', '!', [@empty_group.id.to_s])

        assert_find_issues_with_query_is_successful @query
      end
    end

    context "with 'assigned_to_role' filter" do
      setup do
        @manager_role = Role.find_by_name('Manager')
        @developer_role = Role.find_by_name('Developer')

        @project = Project.generate!
        @manager = User.generate!
        @developer = User.generate!
        @boss = User.generate!
        @guest = User.generate!
        User.add_to_project(@manager, @project, @manager_role)
        User.add_to_project(@developer, @project, @developer_role)
        User.add_to_project(@boss, @project, [@manager_role, @developer_role])
        
        @issue1 = Issue.generate_for_project!(@project, :assigned_to_id => @manager.id)
        @issue2 = Issue.generate_for_project!(@project, :assigned_to_id => @developer.id)
        @issue3 = Issue.generate_for_project!(@project, :assigned_to_id => @boss.id)
        @issue4 = Issue.generate_for_project!(@project, :assigned_to_id => @guest.id)
        @issue5 = Issue.generate_for_project!(@project)
      end

      should "search assigned to for users with the Role" do
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '=', [@manager_role.id.to_s])

        assert_query_result [@issue1, @issue3], @query
      end

      should "search assigned to for users with the Role on the issue project" do
        other_project = Project.generate!
        User.add_to_project(@developer, other_project, @manager_role)
        
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '=', [@manager_role.id.to_s])

        assert_query_result [@issue1, @issue3], @query
      end

      should "return an empty set with empty role" do
        @empty_role = Role.generate!
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '=', [@empty_role.id.to_s])

        assert_query_result [], @query
      end

      should "search assigned to for users without the Role" do
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '!', [@manager_role.id.to_s])

        assert_query_result [@issue2, @issue4, @issue5], @query
      end

      should "search assigned to for users not assigned to any Role (none)" do
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '!*', [''])

        assert_query_result [@issue4, @issue5], @query
      end

      should "search assigned to for users assigned to any Role (all)" do
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '*', [''])

        assert_query_result [@issue1, @issue2, @issue3], @query
      end

      should "return issues with ! empty role" do
        @empty_role = Role.generate!
        @query = Query.new(:name => '_', :project => @project)
        @query.add_filter('assigned_to_role', '!', [@empty_role.id.to_s])

        assert_query_result [@issue1, @issue2, @issue3, @issue4, @issue5], @query
      end
    end
  end

end
