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

class ApiTest::RolesTest < ActionController::IntegrationTest
  fixtures :roles

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/roles" do
    context "GET" do
      context "xml" do
        should "return the roles" do
          get '/roles.xml'

          assert_response :success
          assert_equal 'application/xml', @response.content_type
          assert_equal 3, assigns(:roles).size

          assert_tag :tag => 'roles',
            :attributes => {:type => 'array'},
            :child => {
              :tag => 'role',
              :child => {
                :tag => 'id',
                :content => '2',
                :sibling => {
                  :tag => 'name',
                  :content => 'Developer'
                }
              }
            }
        end
      end

      context "json" do
        should "return the roles" do
          get '/roles.json'

          assert_response :success
          assert_equal 'application/json', @response.content_type
          assert_equal 3, assigns(:roles).size

          json = ActiveSupport::JSON.decode(response.body)
          assert_kind_of Hash, json
          assert_kind_of Array, json['roles']
          assert_include({'id' => 2, 'name' => 'Developer'}, json['roles'])
        end
      end
    end
  end
end
