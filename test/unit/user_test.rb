# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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

class UserTest < ActiveSupport::TestCase
  fixtures :users, :members, :projects, :roles, :member_roles, :auth_sources

  def setup
    @admin = User.find(1)
    @jsmith = User.find(2)
    @dlopper = User.find(3)
  end

  test 'object_daddy creation' do
    User.generate_with_protected!(:firstname => 'Testing connection')
    User.generate_with_protected!(:firstname => 'Testing connection')
    assert_equal 2, User.count(:all, :conditions => {:firstname => 'Testing connection'})
  end
  
  def test_truth
    assert_kind_of User, @jsmith
  end

  def test_create
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    
    user.login = "jsmith"
    user.password, user.password_confirmation = "password", "password"
    # login uniqueness
    assert !user.save
    assert_equal 1, user.errors.count
  
    user.login = "newuser"
    user.password, user.password_confirmation = "passwd", "password"
    # password confirmation
    assert !user.save
    assert_equal 1, user.errors.count

    user.password, user.password_confirmation = "password", "password"
    assert user.save
  end
  
  def test_mail_uniqueness_should_not_be_case_sensitive
    u = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    u.login = 'newuser1'
    u.password, u.password_confirmation = "password", "password"
    assert u.save
    
    u = User.new(:firstname => "new", :lastname => "user", :mail => "newUser@Somenet.foo")
    u.login = 'newuser2'
    u.password, u.password_confirmation = "password", "password"
    assert !u.save
    assert_equal I18n.translate('activerecord.errors.messages.taken'), u.errors.on(:mail)
  end

  def test_update
    assert_equal "admin", @admin.login
    @admin.login = "john"
    assert @admin.save, @admin.errors.full_messages.join("; ")
    @admin.reload
    assert_equal "john", @admin.login
  end
  
  def test_destroy
    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert Member.find_all_by_user_id(2).empty?
  end
  
  def test_validate
    @admin.login = ""
    assert !@admin.save
    assert_equal 1, @admin.errors.count
  end
  
  def test_password
    user = User.try_to_login("admin", "admin")
    assert_kind_of User, user
    assert_equal "admin", user.login
    user.password = "hello"
    assert user.save
    
    user = User.try_to_login("admin", "hello")
    assert_kind_of User, user
    assert_equal "admin", user.login
    assert_equal User.hash_password("hello"), user.hashed_password    
  end
  
  def test_name_format
    assert_equal 'Smith, John', @jsmith.name(:lastname_coma_firstname)
    Setting.user_format = :firstname_lastname
    assert_equal 'John Smith', @jsmith.reload.name
    Setting.user_format = :username
    assert_equal 'jsmith', @jsmith.reload.name
  end
  
  def test_lock
    user = User.try_to_login("jsmith", "jsmith")
    assert_equal @jsmith, user
    
    @jsmith.status = User::STATUS_LOCKED
    assert @jsmith.save
    
    user = User.try_to_login("jsmith", "jsmith")
    assert_equal nil, user  
  end
  
  if ldap_configured?
    context "#try_to_login using LDAP" do
      context "on the fly registration" do
        setup do
          @auth_source = AuthSourceLdap.find(1)
        end

        context "with a successful authentication" do
          should "create a new user account if it doesn't exist" do
            assert_difference('User.count') do
              user = User.try_to_login('edavis', '123456')
              assert !user.admin?
            end
          end
          
          should "retrieve existing user" do
            user = User.try_to_login('edavis', '123456')
            user.admin = true
            user.save!
            
            assert_no_difference('User.count') do
              user = User.try_to_login('edavis', '123456')
              assert user.admin?
            end
          end
        end
      end
    end

  else
    puts "Skipping LDAP tests."
  end
  
  def test_create_anonymous
    AnonymousUser.delete_all
    anon = User.anonymous
    assert !anon.new_record?
    assert_kind_of AnonymousUser, anon
  end

  should_have_one :rss_token

  def test_rss_key
    assert_nil @jsmith.rss_token
    key = @jsmith.rss_key
    assert_equal 40, key.length
    
    @jsmith.reload
    assert_equal key, @jsmith.rss_key
  end

  
  should_have_one :api_token

  context "User#api_key" do
    should "generate a new one if the user doesn't have one" do
      user = User.generate_with_protected!(:api_token => nil)
      assert_nil user.api_token

      key = user.api_key
      assert_equal 40, key.length
      user.reload
      assert_equal key, user.api_key
    end

    should "return the existing api token value" do
      user = User.generate_with_protected!
      token = Token.generate!(:action => 'api')
      user.api_token = token
      assert user.save
      
      assert_equal token.value, user.api_key
    end
  end

  context "User#find_by_api_key" do
    should "return nil if no matching key is found" do
      assert_nil User.find_by_api_key('zzzzzzzzz')
    end

    should "return nil if the key is found for an inactive user" do
      user = User.generate_with_protected!(:status => User::STATUS_LOCKED)
      token = Token.generate!(:action => 'api')
      user.api_token = token
      user.save

      assert_nil User.find_by_api_key(token.value)
    end

    should "return the user if the key is found for an active user" do
      user = User.generate_with_protected!(:status => User::STATUS_ACTIVE)
      token = Token.generate!(:action => 'api')
      user.api_token = token
      user.save
      
      assert_equal user, User.find_by_api_key(token.value)
    end
  end

  def test_roles_for_project
    # user with a role
    roles = @jsmith.roles_for_project(Project.find(1))
    assert_kind_of Role, roles.first
    assert_equal "Manager", roles.first.name
    
    # user with no role
    assert_nil @dlopper.roles_for_project(Project.find(2)).detect {|role| role.member?}
  end
  
  def test_mail_notification_all
    @jsmith.mail_notification = true
    @jsmith.notified_project_ids = []
    @jsmith.save
    @jsmith.reload
    assert @jsmith.projects.first.recipients.include?(@jsmith.mail)
  end
  
  def test_mail_notification_selected
    @jsmith.mail_notification = false
    @jsmith.notified_project_ids = [1]
    @jsmith.save
    @jsmith.reload
    assert Project.find(1).recipients.include?(@jsmith.mail)
  end
  
  def test_mail_notification_none
    @jsmith.mail_notification = false
    @jsmith.notified_project_ids = []
    @jsmith.save
    @jsmith.reload
    assert !@jsmith.projects.first.recipients.include?(@jsmith.mail)
  end
  
  def test_comments_sorting_preference
    assert !@jsmith.wants_comments_in_reverse_order?
    @jsmith.pref.comments_sorting = 'asc'
    assert !@jsmith.wants_comments_in_reverse_order?
    @jsmith.pref.comments_sorting = 'desc'
    assert @jsmith.wants_comments_in_reverse_order?
  end
  
  def test_find_by_mail_should_be_case_insensitive
    u = User.find_by_mail('JSmith@somenet.foo')
    assert_not_nil u
    assert_equal 'jsmith@somenet.foo', u.mail
  end
  
  def test_random_password
    u = User.new
    u.random_password
    assert !u.password.blank?
    assert !u.password_confirmation.blank?
  end
  
  if Object.const_defined?(:OpenID)
    
  def test_setting_identity_url
    normalized_open_id_url = 'http://example.com/'
    u = User.new( :identity_url => 'http://example.com/' )
    assert_equal normalized_open_id_url, u.identity_url
  end

  def test_setting_identity_url_without_trailing_slash
    normalized_open_id_url = 'http://example.com/'
    u = User.new( :identity_url => 'http://example.com' )
    assert_equal normalized_open_id_url, u.identity_url
  end

  def test_setting_identity_url_without_protocol
    normalized_open_id_url = 'http://example.com/'
    u = User.new( :identity_url => 'example.com' )
    assert_equal normalized_open_id_url, u.identity_url
  end
    
  def test_setting_blank_identity_url
    u = User.new( :identity_url => 'example.com' )
    u.identity_url = ''
    assert u.identity_url.blank?
  end
    
  def test_setting_invalid_identity_url
    u = User.new( :identity_url => 'this is not an openid url' )
    assert u.identity_url.blank?
  end
  
  else
    puts "Skipping openid tests."
  end

end
