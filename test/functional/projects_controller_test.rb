# Redmine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

require File.dirname(__FILE__) + '/../test_helper'
require 'projects_controller'

# Re-raise errors caught by the controller.
class ProjectsController; def rescue_action(e) raise e end; end

class ProjectsControllerTest < ActionController::TestCase
  fixtures :projects, :versions, :users, :roles, :members, :member_roles, :issues, :journals, :journal_details,
           :trackers, :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :boards, :messages,
           :attachments, :custom_fields, :custom_values, :time_entries

  def setup
    @controller = ProjectsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.session[:user_id] = nil
    Setting.default_language = 'en'
  end
  
  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:projects)
    
    assert_tag :ul, :child => {:tag => 'li',
                               :descendant => {:tag => 'a', :content => 'eCookbook'},
                               :child => { :tag => 'ul',
                                           :descendant => { :tag => 'a',
                                                            :content => 'Child of private child'
                                                           }
                                          }
                               }
                               
    assert_no_tag :a, :content => /Private child of eCookbook/
  end
  
  def test_index_atom
    get :index, :format => 'atom'
    assert_response :success
    assert_template 'common/feed.atom.rxml'
    assert_select 'feed>title', :text => 'Redmine: Latest projects'
    assert_select 'feed>entry', :count => Project.count(:conditions => Project.visible_by(User.current))
  end
  
  context "#index" do
    context "by non-admin user with view_time_entries permission" do
      setup do
        @request.session[:user_id] = 3
      end
      should "show overall spent time link" do
        get :index
        assert_template 'index'
        assert_tag :a, :attributes => {:href => '/time_entries'}
      end
    end
    
    context "by non-admin user without view_time_entries permission" do
      setup do
        Role.find(2).remove_permission! :view_time_entries
        Role.non_member.remove_permission! :view_time_entries
        Role.anonymous.remove_permission! :view_time_entries
        @request.session[:user_id] = 3
      end
      should "not show overall spent time link" do
        get :index
        assert_template 'index'
        assert_no_tag :a, :attributes => {:href => '/time_entries'}
      end
    end 
  end
  
  context "#add" do
    context "by admin user" do
      setup do
        @request.session[:user_id] = 1
      end
      
      should "accept get" do
        get :add
        assert_response :success
        assert_template 'add'
      end
      
      should "accept post" do
        post :add, :project => { :name => "blog", 
                                 :description => "weblog",
                                 :identifier => "blog",
                                 :is_public => 1,
                                 :custom_field_values => { '3' => 'Beta' }
                                }
        assert_redirected_to '/projects/blog/settings'
        
        project = Project.find_by_name('blog')
        assert_kind_of Project, project
        assert_equal 'weblog', project.description 
        assert_equal true, project.is_public?
        assert_nil project.parent
      end
      
      should "accept post with parent" do
        post :add, :project => { :name => "blog", 
                                 :description => "weblog",
                                 :identifier => "blog",
                                 :is_public => 1,
                                 :custom_field_values => { '3' => 'Beta' },
                                 :parent_id => 1
                                }
        assert_redirected_to '/projects/blog/settings'
        
        project = Project.find_by_name('blog')
        assert_kind_of Project, project
        assert_equal Project.find(1), project.parent
      end
    end
    
    context "by non-admin user with add_project permission" do
      setup do
        Role.non_member.add_permission! :add_project
        @request.session[:user_id] = 9
      end
      
      should "accept get" do
        get :add
        assert_response :success
        assert_template 'add'
        assert_no_tag :select, :attributes => {:name => 'project[parent_id]'}
      end
      
      should "accept post" do
        post :add, :project => { :name => "blog", 
                                 :description => "weblog",
                                 :identifier => "blog",
                                 :is_public => 1,
                                 :custom_field_values => { '3' => 'Beta' }
                                }
        
        assert_redirected_to '/projects/blog/settings'
        
        project = Project.find_by_name('blog')
        assert_kind_of Project, project
        assert_equal 'weblog', project.description 
        assert_equal true, project.is_public?
        
        # User should be added as a project member
        assert User.find(9).member_of?(project)
        assert_equal 1, project.members.size
      end
      
      should "fail with parent_id" do
        assert_no_difference 'Project.count' do
          post :add, :project => { :name => "blog", 
                                   :description => "weblog",
                                   :identifier => "blog",
                                   :is_public => 1,
                                   :custom_field_values => { '3' => 'Beta' },
                                   :parent_id => 1
                                  }
        end
        assert_response :success
        project = assigns(:project)
        assert_kind_of Project, project
        assert_not_nil project.errors.on(:parent_id)
      end
    end
    
    context "by non-admin user with add_subprojects permission" do
      setup do
        Role.find(1).remove_permission! :add_project
        Role.find(1).add_permission! :add_subprojects
        @request.session[:user_id] = 2
      end
      
      should "accept get" do
        get :add, :parent_id => 'ecookbook'
        assert_response :success
        assert_template 'add'
        # parent project selected
        assert_tag :select, :attributes => {:name => 'project[parent_id]'},
                            :child => {:tag => 'option', :attributes => {:value => '1', :selected => 'selected'}}
        # no empty value
        assert_no_tag :select, :attributes => {:name => 'project[parent_id]'},
                               :child => {:tag => 'option', :attributes => {:value => ''}}
      end
      
      should "accept post with parent_id" do
        post :add, :project => { :name => "blog", 
                                 :description => "weblog",
                                 :identifier => "blog",
                                 :is_public => 1,
                                 :custom_field_values => { '3' => 'Beta' },
                                 :parent_id => 1
                                }
        assert_redirected_to '/projects/blog/settings'
        project = Project.find_by_name('blog')
      end
      
      should "fail without parent_id" do
        assert_no_difference 'Project.count' do
          post :add, :project => { :name => "blog", 
                                   :description => "weblog",
                                   :identifier => "blog",
                                   :is_public => 1,
                                   :custom_field_values => { '3' => 'Beta' }
                                  }
        end
        assert_response :success
        project = assigns(:project)
        assert_kind_of Project, project
        assert_not_nil project.errors.on(:parent_id)
      end
      
      should "fail with unauthorized parent_id" do
        assert !User.find(2).member_of?(Project.find(6))
        assert_no_difference 'Project.count' do
          post :add, :project => { :name => "blog", 
                                   :description => "weblog",
                                   :identifier => "blog",
                                   :is_public => 1,
                                   :custom_field_values => { '3' => 'Beta' },
                                   :parent_id => 6
                                  }
        end
        assert_response :success
        project = assigns(:project)
        assert_kind_of Project, project
        assert_not_nil project.errors.on(:parent_id)
      end
    end
  end
  
  def test_show_by_id
    get :show, :id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:project)
  end

  def test_show_by_identifier
    get :show, :id => 'ecookbook'
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:project)
    assert_equal Project.find_by_identifier('ecookbook'), assigns(:project)
  end
  
  def test_show_should_not_fail_when_custom_values_are_nil
    project = Project.find_by_identifier('ecookbook')
    project.custom_values.first.update_attribute(:value, nil)
    get :show, :id => 'ecookbook'
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:project)
    assert_equal Project.find_by_identifier('ecookbook'), assigns(:project)
  end
  
  def test_private_subprojects_hidden
    get :show, :id => 'ecookbook'
    assert_response :success
    assert_template 'show'
    assert_no_tag :tag => 'a', :content => /Private child/
  end

  def test_private_subprojects_visible
    @request.session[:user_id] = 2 # manager who is a member of the private subproject
    get :show, :id => 'ecookbook'
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'a', :content => /Private child/
  end
  
  def test_settings
    @request.session[:user_id] = 2 # manager
    get :settings, :id => 1
    assert_response :success
    assert_template 'settings'
  end
  
  def test_edit
    @request.session[:user_id] = 2 # manager
    post :edit, :id => 1, :project => {:name => 'Test changed name',
                                       :issue_custom_field_ids => ['']}
    assert_redirected_to 'projects/ecookbook/settings'
    project = Project.find(1)
    assert_equal 'Test changed name', project.name
  end
  
  def test_get_destroy
    @request.session[:user_id] = 1 # admin
    get :destroy, :id => 1
    assert_response :success
    assert_template 'destroy'
    assert_not_nil Project.find_by_id(1)
  end

  def test_post_destroy
    @request.session[:user_id] = 1 # admin
    post :destroy, :id => 1, :confirm => 1
    assert_redirected_to 'admin/projects'
    assert_nil Project.find_by_id(1)
  end
  
  def test_archive
    @request.session[:user_id] = 1 # admin
    post :archive, :id => 1
    assert_redirected_to 'admin/projects'
    assert !Project.find(1).active?
  end
  
  def test_unarchive
    @request.session[:user_id] = 1 # admin
    Project.find(1).archive
    post :unarchive, :id => 1
    assert_redirected_to 'admin/projects'
    assert Project.find(1).active?
  end
  
  def test_project_breadcrumbs_should_be_limited_to_3_ancestors
    CustomField.delete_all
    parent = nil
    6.times do |i|
      p = Project.create!(:name => "Breadcrumbs #{i}", :identifier => "breadcrumbs-#{i}")
      p.set_parent!(parent)
      get :show, :id => p
      assert_tag :h1, :parent => { :attributes => {:id => 'header'}},
                      :children => { :count => [i, 3].min,
                                     :only => { :tag => 'a' } }
                                     
      parent = p
    end
  end

  def test_copy_with_project
    @request.session[:user_id] = 1 # admin
    get :copy, :id => 1
    assert_response :success
    assert_template 'copy'
    assert assigns(:project)
    assert_equal Project.find(1).description, assigns(:project).description
    assert_nil assigns(:project).id
  end

  def test_copy_without_project
    @request.session[:user_id] = 1 # admin
    get :copy
    assert_response :redirect
    assert_redirected_to :controller => 'admin', :action => 'projects'
  end

  def test_jump_should_redirect_to_active_tab
    get :show, :id => 1, :jump => 'issues'
    assert_redirected_to 'projects/ecookbook/issues'
  end
  
  def test_jump_should_not_redirect_to_inactive_tab
    get :show, :id => 3, :jump => 'documents'
    assert_response :success
    assert_template 'show'
  end
  
  def test_jump_should_not_redirect_to_unknown_tab
    get :show, :id => 3, :jump => 'foobar'
    assert_response :success
    assert_template 'show'
  end

  # A hook that is manually registered later
  class ProjectBasedTemplate < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context)
      # Adds a project stylesheet
      stylesheet_link_tag(context[:project].identifier) if context[:project]
    end
  end
  # Don't use this hook now
  Redmine::Hook.clear_listeners
  
  def test_hook_response
    Redmine::Hook.add_listener(ProjectBasedTemplate)
    get :show, :id => 1
    assert_tag :tag => 'link', :attributes => {:href => '/stylesheets/ecookbook.css'},
                               :parent => {:tag => 'head'}
    
    Redmine::Hook.clear_listeners
  end
end
