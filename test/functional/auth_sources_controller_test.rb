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

class AuthSourcesControllerTest < ActionController::TestCase
  fixtures :users, :auth_sources

  def setup
    @request.session[:user_id] = 1
  end

  def test_index
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:auth_sources)
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    source = assigns(:auth_source)
    assert_equal AuthSourceLdap, source.class
    assert source.new_record?

    assert_tag 'input', :attributes => {:name => 'type', :value => 'AuthSourceLdap'}
    assert_tag 'input', :attributes => {:name => 'auth_source[host]'}
  end

  def test_create
    assert_difference 'AuthSourceLdap.count' do
      post :create, :type => 'AuthSourceLdap', :auth_source => {:name => 'Test', :host => '127.0.0.1', :port => '389', :attr_login => 'cn'}
      assert_redirected_to '/auth_sources'
    end

    source = AuthSourceLdap.first(:order => 'id DESC')
    assert_equal 'Test', source.name
    assert_equal '127.0.0.1', source.host
    assert_equal 389, source.port
    assert_equal 'cn', source.attr_login
  end

  def test_create_with_failure
    assert_no_difference 'AuthSourceLdap.count' do
      post :create, :type => 'AuthSourceLdap', :auth_source => {:name => 'Test', :host => '', :port => '389', :attr_login => 'cn'}
      assert_response :success
      assert_template 'new'
    end
    assert_error_tag :content => /host can&#x27;t be blank/i
  end

  def test_edit
    get :edit, :id => 1

    assert_response :success
    assert_template 'edit'

    assert_tag 'input', :attributes => {:name => 'auth_source[host]'}
  end

  def test_update
    put :update, :id => 1, :auth_source => {:name => 'Renamed', :host => '192.168.0.10', :port => '389', :attr_login => 'uid'}
    assert_redirected_to '/auth_sources'

    source = AuthSourceLdap.find(1)
    assert_equal 'Renamed', source.name
    assert_equal '192.168.0.10', source.host
  end

  def test_update_with_failure
    put :update, :id => 1, :auth_source => {:name => 'Renamed', :host => '', :port => '389', :attr_login => 'uid'}
    assert_response :success
    assert_template 'edit'
    assert_error_tag :content => /host can&#x27;t be blank/i
  end

  def test_destroy
    assert_difference 'AuthSourceLdap.count', -1 do
      delete :destroy, :id => 1
    end
  end

  def test_destroy_auth_source_in_use
    User.find(2).update_attribute :auth_source_id, 1

    assert_no_difference 'AuthSourceLdap.count' do
      delete :destroy, :id => 1
    end
  end

  def test_test_connection
    AuthSourceLdap.any_instance.stubs(:test_connection).returns(true)

    get :test_connection, :id => 1
    assert_redirected_to '/auth_sources'
    assert_not_nil flash[:notice]
    assert_match /successful/i, flash[:notice]
  end

  def test_test_connection_with_failure
    AuthSourceLdap.any_instance.stubs(:initialize_ldap_con).raises(Net::LDAP::LdapError.new("Something went wrong"))

    get :test_connection, :id => 1
    assert_redirected_to '/auth_sources'
    assert_not_nil flash[:error]
    assert_include 'Something went wrong', flash[:error]
  end
end
