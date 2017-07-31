# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class WikisControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules, :wikis

  def setup
    User.current = nil
  end

  def test_create
    @request.session[:user_id] = 1
    assert_nil Project.find(3).wiki

    assert_difference 'Wiki.count' do
      post :edit, :params => {:id => 3, :wiki => { :start_page => 'Start page' }}, :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end

    wiki = Project.find(3).wiki
    assert_not_nil wiki
    assert_equal 'Start page', wiki.start_page
  end

  def test_create_with_failure
    @request.session[:user_id] = 1

    assert_no_difference 'Wiki.count' do
      post :edit, :params => {:id => 3, :wiki => { :start_page => '' }}, :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end

    assert_include 'errorExplanation', response.body
    assert_include "Start page cannot be blank", response.body
  end

  def test_update
    @request.session[:user_id] = 1

    assert_no_difference 'Wiki.count' do
      post :edit, :params => {:id => 1, :wiki => { :start_page => 'Other start page' }}, :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end

    wiki = Project.find(1).wiki
    assert_equal 'Other start page', wiki.start_page
  end

  def test_get_destroy_should_ask_confirmation
    @request.session[:user_id] = 1
    assert_no_difference 'Wiki.count' do
      get :destroy, :params => {:id => 1}
      assert_response :success
    end
  end

  def test_post_destroy_should_delete_wiki
    @request.session[:user_id] = 1
    post :destroy, :params => {:id => 1, :confirm => 1}
    assert_redirected_to :controller => 'projects',
                         :action => 'settings', :id => 'ecookbook', :tab => 'wiki'
    assert_nil Project.find(1).wiki
  end

  def test_not_found
    @request.session[:user_id] = 1
    post :destroy, :params => {:id => 999, :confirm => 1}
    assert_response 404
  end
end
