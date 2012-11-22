# -*- coding: utf-8 -*-
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
require 'timelog_controller'

# Re-raise errors caught by the controller.
class TimelogController; def rescue_action(e) raise e end; end

class TimelogControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules, :roles, :members,
           :member_roles, :issues, :time_entries, :users,
           :trackers, :enumerations, :issue_statuses,
           :custom_fields, :custom_values

  include Redmine::I18n

  def setup
    @controller = TimelogController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_new_with_project_id
    @request.session[:user_id] = 3
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'
    assert_select 'select[name=?]', 'time_entry[project_id]', 0
    assert_select 'input[name=?][value=1][type=hidden]', 'time_entry[project_id]'
  end

  def test_new_with_issue_id
    @request.session[:user_id] = 3
    get :new, :issue_id => 2
    assert_response :success
    assert_template 'new'
    assert_select 'select[name=?]', 'time_entry[project_id]', 0
    assert_select 'input[name=?][value=1][type=hidden]', 'time_entry[project_id]'
  end

  def test_new_without_project
    @request.session[:user_id] = 3
    get :new
    assert_response :success
    assert_template 'new'
    assert_select 'select[name=?]', 'time_entry[project_id]'
    assert_select 'input[name=?]', 'time_entry[project_id]', 0
  end

  def test_new_without_project_should_prefill_the_form
    @request.session[:user_id] = 3
    get :new, :time_entry => {:project_id => '1'}
    assert_response :success
    assert_template 'new'
    assert_select 'select[name=?]', 'time_entry[project_id]' do
      assert_select 'option[value=1][selected=selected]'
    end
    assert_select 'input[name=?]', 'time_entry[project_id]', 0
  end

  def test_new_without_project_should_deny_without_permission
    Role.all.each {|role| role.remove_permission! :log_time}
    @request.session[:user_id] = 3

    get :new
    assert_response 403
  end

  def test_new_should_select_default_activity
    @request.session[:user_id] = 3
    get :new, :project_id => 1
    assert_response :success
    assert_select 'select[name=?]', 'time_entry[activity_id]' do
      assert_select 'option[selected=selected]', :text => 'Development'
    end
  end

  def test_new_should_only_show_active_time_entry_activities
    @request.session[:user_id] = 3
    get :new, :project_id => 1
    assert_response :success
    assert_no_tag 'option', :content => 'Inactive Activity'
  end

  def test_get_edit_existing_time
    @request.session[:user_id] = 2
    get :edit, :id => 2, :project_id => nil
    assert_response :success
    assert_template 'edit'
    # Default activity selected
    assert_tag :tag => 'form', :attributes => { :action => '/projects/ecookbook/time_entries/2' }
  end

  def test_get_edit_with_an_existing_time_entry_with_inactive_activity
    te = TimeEntry.find(1)
    te.activity = TimeEntryActivity.find_by_name("Inactive Activity")
    te.save!

    @request.session[:user_id] = 1
    get :edit, :project_id => 1, :id => 1
    assert_response :success
    assert_template 'edit'
    # Blank option since nothing is pre-selected
    assert_tag :tag => 'option', :content => '--- Please select ---'
  end

  def test_post_create
    # TODO: should POST to issues’ time log instead of project. change form
    # and routing
    @request.session[:user_id] = 3
    post :create, :project_id => 1,
                :time_entry => {:comments => 'Some work on TimelogControllerTest',
                                # Not the default activity
                                :activity_id => '11',
                                :spent_on => '2008-03-14',
                                :issue_id => '1',
                                :hours => '7.3'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'

    i = Issue.find(1)
    t = TimeEntry.find_by_comments('Some work on TimelogControllerTest')
    assert_not_nil t
    assert_equal 11, t.activity_id
    assert_equal 7.3, t.hours
    assert_equal 3, t.user_id
    assert_equal i, t.issue
    assert_equal i.project, t.project
  end

  def test_post_create_with_blank_issue
    # TODO: should POST to issues’ time log instead of project. change form
    # and routing
    @request.session[:user_id] = 3
    post :create, :project_id => 1,
                :time_entry => {:comments => 'Some work on TimelogControllerTest',
                                # Not the default activity
                                :activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'

    t = TimeEntry.find_by_comments('Some work on TimelogControllerTest')
    assert_not_nil t
    assert_equal 11, t.activity_id
    assert_equal 7.3, t.hours
    assert_equal 3, t.user_id
  end

  def test_create_and_continue
    @request.session[:user_id] = 2
    post :create, :project_id => 1,
                :time_entry => {:activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'},
                :continue => '1'
    assert_redirected_to '/projects/ecookbook/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D='
  end

  def test_create_and_continue_with_issue_id
    @request.session[:user_id] = 2
    post :create, :project_id => 1,
                :time_entry => {:activity_id => '11',
                                :issue_id => '1',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'},
                :continue => '1'
    assert_redirected_to '/projects/ecookbook/issues/1/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=1'
  end

  def test_create_and_continue_without_project
    @request.session[:user_id] = 2
    post :create, :time_entry => {:project_id => '1',
                                :activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'},
                  :continue => '1'

    assert_redirected_to '/time_entries/new?time_entry%5Bactivity_id%5D=11&time_entry%5Bissue_id%5D=&time_entry%5Bproject_id%5D=1'
  end

  def test_create_without_log_time_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :log_time
    post :create, :project_id => 1,
                :time_entry => {:activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'}

    assert_response 403
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    post :create, :project_id => 1,
                :time_entry => {:activity_id => '',
                                :issue_id => '',
                                :spent_on => '2008-03-14',
                                :hours => '7.3'}

    assert_response :success
    assert_template 'new'
  end

  def test_create_without_project
    @request.session[:user_id] = 2
    assert_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                  :activity_id => '11',
                                  :issue_id => '',
                                  :spent_on => '2008-03-14',
                                  :hours => '7.3'}
    end

    assert_redirected_to '/projects/ecookbook/time_entries'
    time_entry = TimeEntry.first(:order => 'id DESC')
    assert_equal 1, time_entry.project_id
  end

  def test_create_without_project_should_fail_with_issue_not_inside_project
    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                  :activity_id => '11',
                                  :issue_id => '5',
                                  :spent_on => '2008-03-14',
                                  :hours => '7.3'}
    end

    assert_response :success
    assert assigns(:time_entry).errors[:issue_id].present?
  end

  def test_create_without_project_should_deny_without_permission
    @request.session[:user_id] = 2
    Project.find(3).disable_module!(:time_tracking)

    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '3',
                                  :activity_id => '11',
                                  :issue_id => '',
                                  :spent_on => '2008-03-14',
                                  :hours => '7.3'}
    end

    assert_response 403
  end

  def test_create_without_project_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'TimeEntry.count' do
      post :create, :time_entry => {:project_id => '1',
                                  :activity_id => '11',
                                  :issue_id => '',
                                  :spent_on => '2008-03-14',
                                  :hours => ''}
    end

    assert_response :success
    assert_tag 'select', :attributes => {:name => 'time_entry[project_id]'},
      :child => {:tag => 'option', :attributes => {:value => '1', :selected => 'selected'}}
  end

  def test_update
    entry = TimeEntry.find(1)
    assert_equal 1, entry.issue_id
    assert_equal 2, entry.user_id

    @request.session[:user_id] = 1
    put :update, :id => 1,
                :time_entry => {:issue_id => '2',
                                :hours => '8'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    entry.reload

    assert_equal 8, entry.hours
    assert_equal 2, entry.issue_id
    assert_equal 2, entry.user_id
  end

  def test_get_bulk_edit
    @request.session[:user_id] = 2
    get :bulk_edit, :ids => [1, 2]
    assert_response :success
    assert_template 'bulk_edit'

    # System wide custom field
    assert_tag :select, :attributes => {:name => 'time_entry[custom_field_values][10]'}

    # Activities
    assert_select 'select[name=?]', 'time_entry[activity_id]' do
      assert_select 'option[value=]', :text => '(No change)'
      assert_select 'option[value=9]', :text => 'Design'
    end
  end

  def test_get_bulk_edit_on_different_projects
    @request.session[:user_id] = 2
    get :bulk_edit, :ids => [1, 2, 6]
    assert_response :success
    assert_template 'bulk_edit'
  end

  def test_bulk_update
    @request.session[:user_id] = 2
    # update time entry activity
    post :bulk_update, :ids => [1, 2], :time_entry => { :activity_id => 9}

    assert_response 302
    # check that the issues were updated
    assert_equal [9, 9], TimeEntry.find_all_by_id([1, 2]).collect {|i| i.activity_id}
  end

  def test_bulk_update_with_failure
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1, 2], :time_entry => { :hours => 'A'}

    assert_response 302
    assert_match /Failed to save 2 time entrie/, flash[:error]
  end

  def test_bulk_update_on_different_projects
    @request.session[:user_id] = 2
    # makes user a manager on the other project
    Member.create!(:user_id => 2, :project_id => 3, :role_ids => [1])
    
    # update time entry activity
    post :bulk_update, :ids => [1, 2, 4], :time_entry => { :activity_id => 9 }

    assert_response 302
    # check that the issues were updated
    assert_equal [9, 9, 9], TimeEntry.find_all_by_id([1, 2, 4]).collect {|i| i.activity_id}
  end

  def test_bulk_update_on_different_projects_without_rights
    @request.session[:user_id] = 3
    user = User.find(3)
    action = { :controller => "timelog", :action => "bulk_update" }
    assert user.allowed_to?(action, TimeEntry.find(1).project)
    assert ! user.allowed_to?(action, TimeEntry.find(5).project)
    post :bulk_update, :ids => [1, 5], :time_entry => { :activity_id => 9 }
    assert_response 403
  end

  def test_bulk_update_custom_field
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1, 2], :time_entry => { :custom_field_values => {'10' => '0'} }

    assert_response 302
    assert_equal ["0", "0"], TimeEntry.find_all_by_id([1, 2]).collect {|i| i.custom_value_for(10).value}
  end

  def test_post_bulk_update_should_redirect_back_using_the_back_url_parameter
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1,2], :back_url => '/time_entries'

    assert_response :redirect
    assert_redirected_to '/time_entries'
  end

  def test_post_bulk_update_should_not_redirect_back_using_the_back_url_parameter_off_the_host
    @request.session[:user_id] = 2
    post :bulk_update, :ids => [1,2], :back_url => 'http://google.com'

    assert_response :redirect
    assert_redirected_to :controller => 'timelog', :action => 'index', :project_id => Project.find(1).identifier
  end

  def test_post_bulk_update_without_edit_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    post :bulk_update, :ids => [1,2]

    assert_response 403
  end

  def test_destroy
    @request.session[:user_id] = 2
    delete :destroy, :id => 1
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal I18n.t(:notice_successful_delete), flash[:notice]
    assert_nil TimeEntry.find_by_id(1)
  end

  def test_destroy_should_fail
    # simulate that this fails (e.g. due to a plugin), see #5700
    TimeEntry.any_instance.expects(:destroy).returns(false)

    @request.session[:user_id] = 2
    delete :destroy, :id => 1
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_equal I18n.t(:notice_unable_delete_time_entry), flash[:error]
    assert_not_nil TimeEntry.find_by_id(1)
  end

  def test_index_all_projects
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
    assert_tag :form,
      :attributes => {:action => "/time_entries", :id => 'query_form'}
  end

  def test_index_all_projects_should_show_log_time_link
    @request.session[:user_id] = 2
    get :index
    assert_response :success
    assert_template 'index'
    assert_tag 'a', :attributes => {:href => '/time_entries/new'}, :content => /Log time/
  end

  def test_index_at_project_level
    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 4, assigns(:entries).size
    # project and subproject
    assert_equal [1, 3], assigns(:entries).collect(&:project_id).uniq.sort
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
    # display all time by default
    assert_nil assigns(:from)
    assert_nil assigns(:to)
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/time_entries", :id => 'query_form'}
  end

  def test_index_at_project_level_with_date_range
    get :index, :project_id => 'ecookbook', :from => '2007-03-20', :to => '2007-04-30'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 3, assigns(:entries).size
    assert_not_nil assigns(:total_hours)
    assert_equal "12.90", "%.2f" % assigns(:total_hours)
    assert_equal '2007-03-20'.to_date, assigns(:from)
    assert_equal '2007-04-30'.to_date, assigns(:to)
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/time_entries", :id => 'query_form'}
  end

  def test_index_at_project_level_with_period
    get :index, :project_id => 'ecookbook', :period => '7_days'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_not_nil assigns(:total_hours)
    assert_equal Date.today - 7, assigns(:from)
    assert_equal Date.today, assigns(:to)
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/time_entries", :id => 'query_form'}
  end

  def test_index_one_day
    get :index, :project_id => 'ecookbook', :from => "2007-03-23", :to => "2007-03-23"
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:total_hours)
    assert_equal "4.25", "%.2f" % assigns(:total_hours)
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/time_entries", :id => 'query_form'}
  end

  def test_index_from_a_date
    get :index, :project_id => 'ecookbook', :from => "2007-03-23", :to => ""
    assert_equal '2007-03-23'.to_date, assigns(:from)
    assert_nil assigns(:to)
  end

  def test_index_to_a_date
    get :index, :project_id => 'ecookbook', :from => "", :to => "2007-03-23"
    assert_nil assigns(:from)
    assert_equal '2007-03-23'.to_date, assigns(:to)
  end

  def test_index_today
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'today'
    assert_equal '2011-12-15'.to_date, assigns(:from)
    assert_equal '2011-12-15'.to_date, assigns(:to)
  end

  def test_index_yesterday
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'yesterday'
    assert_equal '2011-12-14'.to_date, assigns(:from)
    assert_equal '2011-12-14'.to_date, assigns(:to)
  end

  def test_index_current_week
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'current_week'
    assert_equal '2011-12-12'.to_date, assigns(:from)
    assert_equal '2011-12-18'.to_date, assigns(:to)
  end

  def test_index_last_week
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'current_week'
    assert_equal '2011-12-05'.to_date, assigns(:from)
    assert_equal '2011-12-11'.to_date, assigns(:to)
  end

  def test_index_last_week
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'last_week'
    assert_equal '2011-12-05'.to_date, assigns(:from)
    assert_equal '2011-12-11'.to_date, assigns(:to)
  end

  def test_index_7_days
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => '7_days'
    assert_equal '2011-12-08'.to_date, assigns(:from)
    assert_equal '2011-12-15'.to_date, assigns(:to)
  end

  def test_index_current_month
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'current_month'
    assert_equal '2011-12-01'.to_date, assigns(:from)
    assert_equal '2011-12-31'.to_date, assigns(:to)
  end

  def test_index_last_month
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'last_month'
    assert_equal '2011-11-01'.to_date, assigns(:from)
    assert_equal '2011-11-30'.to_date, assigns(:to)
  end

  def test_index_30_days
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => '30_days'
    assert_equal '2011-11-15'.to_date, assigns(:from)
    assert_equal '2011-12-15'.to_date, assigns(:to)
  end

  def test_index_current_year
    Date.stubs(:today).returns('2011-12-15'.to_date)
    get :index, :period => 'current_year'
    assert_equal '2011-01-01'.to_date, assigns(:from)
    assert_equal '2011-12-31'.to_date, assigns(:to)
  end

  def test_index_at_issue_level
    get :index, :issue_id => 1
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:entries)
    assert_equal 2, assigns(:entries).size
    assert_not_nil assigns(:total_hours)
    assert_equal 154.25, assigns(:total_hours)
    # display all time
    assert_nil assigns(:from)
    assert_nil assigns(:to)
    # TODO: remove /projects/:project_id/issues/:issue_id/time_entries routes
    # to use /issues/:issue_id/time_entries
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/issues/1/time_entries", :id => 'query_form'}
  end

  def test_index_should_sort_by_spent_on_and_created_on
    t1 = TimeEntry.create!(:user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-16', :created_on => '2012-06-16 20:00:00', :activity_id => 10)
    t2 = TimeEntry.create!(:user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-16', :created_on => '2012-06-16 20:05:00', :activity_id => 10)
    t3 = TimeEntry.create!(:user => User.find(1), :project => Project.find(1), :hours => 1, :spent_on => '2012-06-15', :created_on => '2012-06-16 20:10:00', :activity_id => 10)

    get :index, :project_id => 1, :from => '2012-06-15', :to => '2012-06-16'
    assert_response :success
    assert_equal [t2, t1, t3], assigns(:entries)

    get :index, :project_id => 1, :from => '2012-06-15', :to => '2012-06-16', :sort => 'spent_on'
    assert_response :success
    assert_equal [t3, t1, t2], assigns(:entries)
  end

  def test_index_atom_feed
    get :index, :project_id => 1, :format => 'atom'
    assert_response :success
    assert_equal 'application/atom+xml', @response.content_type
    assert_not_nil assigns(:items)
    assert assigns(:items).first.is_a?(TimeEntry)
  end

  def test_index_all_projects_csv_export
    Setting.date_format = '%m/%d/%Y'
    get :index, :format => 'csv'
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    assert @response.body.include?("Date,User,Activity,Project,Issue,Tracker,Subject,Hours,Comment,Overtime\n")
    assert @response.body.include?("\n04/21/2007,redMine Admin,Design,eCookbook,3,Bug,Error 281 when updating a recipe,1.0,\"\",\"\"\n")
  end

  def test_index_csv_export
    Setting.date_format = '%m/%d/%Y'
    get :index, :project_id => 1, :format => 'csv'
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    assert @response.body.include?("Date,User,Activity,Project,Issue,Tracker,Subject,Hours,Comment,Overtime\n")
    assert @response.body.include?("\n04/21/2007,redMine Admin,Design,eCookbook,3,Bug,Error 281 when updating a recipe,1.0,\"\",\"\"\n")
  end

  def test_index_csv_export_with_multi_custom_field
    field = TimeEntryCustomField.create!(:name => 'Test', :field_format => 'list',
      :multiple => true, :possible_values => ['value1', 'value2'])
    entry = TimeEntry.find(1)
    entry.custom_field_values = {field.id => ['value1', 'value2']}
    entry.save!

    get :index, :project_id => 1, :format => 'csv'
    assert_response :success
    assert_include '"value1, value2"', @response.body
  end

  def test_csv_big_5
    user = User.find_by_id(3)
    user.language = "zh-TW"
    assert user.save
    str_utf8  = "\xe4\xb8\x80\xe6\x9c\x88"
    str_big5  = "\xa4@\xa4\xeb"
    if str_utf8.respond_to?(:force_encoding)
      str_utf8.force_encoding('UTF-8')
      str_big5.force_encoding('Big5')
    end
    @request.session[:user_id] = 3
    post :create, :project_id => 1,
                :time_entry => {:comments => str_utf8,
                                # Not the default activity
                                :activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2011-11-10',
                                :hours => '7.3'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'

    t = TimeEntry.find_by_comments(str_utf8)
    assert_not_nil t
    assert_equal 11, t.activity_id
    assert_equal 7.3, t.hours
    assert_equal 3, t.user_id

    get :index, :project_id => 1, :format => 'csv',
        :from => '2011-11-10', :to => '2011-11-10'
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    ar = @response.body.chomp.split("\n")
    s1 = "\xa4\xe9\xb4\xc1"
    if str_utf8.respond_to?(:force_encoding)
      s1.force_encoding('Big5')
    end
    assert ar[0].include?(s1)
    assert ar[1].include?(str_big5)
  end

  def test_csv_cannot_convert_should_be_replaced_big_5
    user = User.find_by_id(3)
    user.language = "zh-TW"
    assert user.save
    str_utf8  = "\xe4\xbb\xa5\xe5\x86\x85"
    if str_utf8.respond_to?(:force_encoding)
      str_utf8.force_encoding('UTF-8')
    end
    @request.session[:user_id] = 3
    post :create, :project_id => 1,
                :time_entry => {:comments => str_utf8,
                                # Not the default activity
                                :activity_id => '11',
                                :issue_id => '',
                                :spent_on => '2011-11-10',
                                :hours => '7.3'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'

    t = TimeEntry.find_by_comments(str_utf8)
    assert_not_nil t
    assert_equal 11, t.activity_id
    assert_equal 7.3, t.hours
    assert_equal 3, t.user_id

    get :index, :project_id => 1, :format => 'csv',
        :from => '2011-11-10', :to => '2011-11-10'
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    ar = @response.body.chomp.split("\n")
    s1 = "\xa4\xe9\xb4\xc1"
    if str_utf8.respond_to?(:force_encoding)
      s1.force_encoding('Big5')
    end
    assert ar[0].include?(s1)
    s2 = ar[1].split(",")[8]
    if s2.respond_to?(:force_encoding)
      s3 = "\xa5H?"
      s3.force_encoding('Big5')
      assert_equal s3, s2
    elsif RUBY_PLATFORM == 'java'
      assert_equal "??", s2
    else
      assert_equal "\xa5H???", s2
    end
  end

  def test_csv_tw
    with_settings :default_language => "zh-TW" do
      str1  = "test_csv_tw"
      user = User.find_by_id(3)
      te1 = TimeEntry.create(:spent_on => '2011-11-10',
                             :hours    => 999.9,
                             :project  => Project.find(1),
                             :user     => user,
                             :activity => TimeEntryActivity.find_by_name('Design'),
                             :comments => str1)
      te2 = TimeEntry.find_by_comments(str1)
      assert_not_nil te2
      assert_equal 999.9, te2.hours
      assert_equal 3, te2.user_id

      get :index, :project_id => 1, :format => 'csv',
          :from => '2011-11-10', :to => '2011-11-10'
      assert_response :success
      assert_equal 'text/csv; header=present', @response.content_type

      ar = @response.body.chomp.split("\n")
      s2 = ar[1].split(",")[7]
      assert_equal '999.9', s2

      str_tw = "Traditional Chinese (\xe7\xb9\x81\xe9\xab\x94\xe4\xb8\xad\xe6\x96\x87)"
      if str_tw.respond_to?(:force_encoding)
        str_tw.force_encoding('UTF-8')
      end
      assert_equal str_tw, l(:general_lang_name)
      assert_equal ',', l(:general_csv_separator)
      assert_equal '.', l(:general_csv_decimal_separator)
    end
  end

  def test_csv_fr
    with_settings :default_language => "fr" do
      str1  = "test_csv_fr"
      user = User.find_by_id(3)
      te1 = TimeEntry.create(:spent_on => '2011-11-10',
                             :hours    => 999.9,
                             :project  => Project.find(1),
                             :user     => user,
                             :activity => TimeEntryActivity.find_by_name('Design'),
                             :comments => str1)
      te2 = TimeEntry.find_by_comments(str1)
      assert_not_nil te2
      assert_equal 999.9, te2.hours
      assert_equal 3, te2.user_id

      get :index, :project_id => 1, :format => 'csv',
          :from => '2011-11-10', :to => '2011-11-10'
      assert_response :success
      assert_equal 'text/csv; header=present', @response.content_type

      ar = @response.body.chomp.split("\n")
      s2 = ar[1].split(";")[7]
      assert_equal '999,9', s2

      str_fr = "Fran\xc3\xa7ais"
      if str_fr.respond_to?(:force_encoding)
        str_fr.force_encoding('UTF-8')
      end
      assert_equal str_fr, l(:general_lang_name)
      assert_equal ';', l(:general_csv_separator)
      assert_equal ',', l(:general_csv_decimal_separator)
    end
  end
end
