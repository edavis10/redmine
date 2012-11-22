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

class EnumerationsControllerTest < ActionController::TestCase
  fixtures :enumerations, :issues, :users

  def setup
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_new
    get :new, :type => 'IssuePriority'
    assert_response :success
    assert_template 'new'
    assert_kind_of IssuePriority, assigns(:enumeration)
    assert_tag 'input', :attributes => {:name => 'enumeration[type]', :value => 'IssuePriority'}
    assert_tag 'input', :attributes => {:name => 'enumeration[name]'}
  end

  def test_new_with_invalid_type_should_respond_with_404
    get :new, :type => 'UnknownType'
    assert_response 404
  end

  def test_create
    assert_difference 'IssuePriority.count' do
      post :create, :enumeration => {:type => 'IssuePriority', :name => 'Lowest'}
    end
    assert_redirected_to '/enumerations?type=IssuePriority'
    e = IssuePriority.find_by_name('Lowest')
    assert_not_nil e
  end

  def test_create_with_failure
    assert_no_difference 'IssuePriority.count' do
      post :create, :enumeration => {:type => 'IssuePriority', :name => ''}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_edit
    get :edit, :id => 6
    assert_response :success
    assert_template 'edit'
    assert_tag 'input', :attributes => {:name => 'enumeration[name]', :value => 'High'}
  end

  def test_edit_invalid_should_respond_with_404
    get :edit, :id => 999
    assert_response 404
  end

  def test_update
    assert_no_difference 'IssuePriority.count' do
      put :update, :id => 6, :enumeration => {:type => 'IssuePriority', :name => 'New name'}
    end
    assert_redirected_to '/enumerations?type=IssuePriority'
    e = IssuePriority.find(6)
    assert_equal 'New name', e.name
  end

  def test_update_with_failure
    assert_no_difference 'IssuePriority.count' do
      put :update, :id => 6, :enumeration => {:type => 'IssuePriority', :name => ''}
    end
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy_enumeration_not_in_use
    assert_difference 'IssuePriority.count', -1 do
      delete :destroy, :id => 7
    end
    assert_redirected_to :controller => 'enumerations', :action => 'index'
    assert_nil Enumeration.find_by_id(7)
  end

  def test_destroy_enumeration_in_use
    assert_no_difference 'IssuePriority.count' do
      delete :destroy, :id => 4
    end
    assert_response :success
    assert_template 'destroy'
    assert_not_nil Enumeration.find_by_id(4)
    assert_select 'select[name=reassign_to_id]' do
      assert_select 'option[value=6]', :text => 'High'
    end
  end

  def test_destroy_enumeration_in_use_with_reassignment
    issue = Issue.find(:first, :conditions => {:priority_id => 4})
    assert_difference 'IssuePriority.count', -1 do
      delete :destroy, :id => 4, :reassign_to_id => 6
    end
    assert_redirected_to :controller => 'enumerations', :action => 'index'
    assert_nil Enumeration.find_by_id(4)
    # check that the issue was reassign
    assert_equal 6, issue.reload.priority_id
  end
end
