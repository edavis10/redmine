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

require File.expand_path('../../../test_helper', __FILE__)

class ApiTest::GroupsTest < ActionController::IntegrationTest
  fixtures :users, :groups_users

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "GET /groups" do
    context ".xml" do
      should "require authentication" do
        get '/groups.xml'
        assert_response 401
      end

      should "return groups" do
        get '/groups.xml', {}, credentials('admin')
        assert_response :success
        assert_equal 'application/xml', response.content_type

        assert_select 'groups' do
          assert_select 'group' do
            assert_select 'name', :text => 'A Team'
            assert_select 'id', :text => '10'
          end
        end
      end
    end

    context ".json" do
      should "require authentication" do
        get '/groups.json'
        assert_response 401
      end

      should "return groups" do
        get '/groups.json', {}, credentials('admin')
        assert_response :success
        assert_equal 'application/json', response.content_type

        json = MultiJson.load(response.body)
        groups = json['groups']
        assert_kind_of Array, groups
        group = groups.detect {|g| g['name'] == 'A Team'}
        assert_not_nil group
        assert_equal({'id' => 10, 'name' => 'A Team'}, group)
      end
    end
  end

  context "GET /groups/:id" do
    context ".xml" do
      should "return the group with its users" do
        get '/groups/10.xml', {}, credentials('admin')
        assert_response :success
        assert_equal 'application/xml', response.content_type

        assert_select 'group' do
          assert_select 'name', :text => 'A Team'
          assert_select 'id', :text => '10'
        end
      end

      should "include users if requested" do
        get '/groups/10.xml?include=users', {}, credentials('admin')
        assert_response :success
        assert_equal 'application/xml', response.content_type

        assert_select 'group' do
          assert_select 'users' do
            assert_select 'user', Group.find(10).users.count
            assert_select 'user[id=8]'
          end
        end
      end

      should "include memberships if requested" do
        get '/groups/10.xml?include=memberships', {}, credentials('admin')
        assert_response :success
        assert_equal 'application/xml', response.content_type

        assert_select 'group' do
          assert_select 'memberships'
        end
      end
    end
  end

  context "POST /groups" do
    context "with valid parameters" do
      context ".xml" do
        should "create groups" do
          assert_difference('Group.count') do
            post '/groups.xml', {:group => {:name => 'Test', :user_ids => [2, 3]}}, credentials('admin')
            assert_response :created
            assert_equal 'application/xml', response.content_type
          end
  
          group = Group.order('id DESC').first
          assert_equal 'Test', group.name
          assert_equal [2, 3], group.users.map(&:id).sort

          assert_select 'group' do
            assert_select 'name', :text => 'Test'
          end
        end
      end
    end

    context "with invalid parameters" do
      context ".xml" do
        should "return errors" do
          assert_no_difference('Group.count') do
            post '/groups.xml', {:group => {:name => ''}}, credentials('admin')
          end
          assert_response :unprocessable_entity
          assert_equal 'application/xml', response.content_type

          assert_select 'errors' do
            assert_select 'error', :text => /Name can't be blank/
          end
        end
      end
    end
  end

  context "PUT /groups/:id" do
    context "with valid parameters" do
      context ".xml" do
        should "update the group" do
          put '/groups/10.xml', {:group => {:name => 'New name', :user_ids => [2, 3]}}, credentials('admin')
          assert_response :ok
          assert_equal '', @response.body
  
          group = Group.find(10)
          assert_equal 'New name', group.name
          assert_equal [2, 3], group.users.map(&:id).sort
        end
      end
    end

    context "with invalid parameters" do
      context ".xml" do
        should "return errors" do
          put '/groups/10.xml', {:group => {:name => ''}}, credentials('admin')
          assert_response :unprocessable_entity
          assert_equal 'application/xml', response.content_type

          assert_select 'errors' do
            assert_select 'error', :text => /Name can't be blank/
          end
        end
      end
    end
  end

  context "DELETE /groups/:id" do
    context ".xml" do
      should "delete the group" do
        assert_difference 'Group.count', -1 do
          delete '/groups/10.xml', {}, credentials('admin')
          assert_response :ok
          assert_equal '', @response.body
        end
      end
    end
  end

  context "POST /groups/:id/users" do
    context ".xml" do
      should "add user to the group" do
        assert_difference 'Group.find(10).users.count' do
          post '/groups/10/users.xml', {:user_id => 5}, credentials('admin')
          assert_response :ok
          assert_equal '', @response.body
        end
        assert_include User.find(5), Group.find(10).users
      end
    end
  end

  context "DELETE /groups/:id/users/:user_id" do
    context ".xml" do
      should "remove user from the group" do
        assert_difference 'Group.find(10).users.count', -1 do
          delete '/groups/10/users/8.xml', {}, credentials('admin')
          assert_response :ok
          assert_equal '', @response.body
        end
        assert_not_include User.find(8), Group.find(10).users
      end
    end
  end
end
