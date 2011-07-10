# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

class ApiTest::QueriesTest < ActionController::IntegrationTest
  fixtures :all

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/queries" do
    context "GET" do
      
      should "return queries" do
        get '/queries.xml'
        
        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag :tag => 'queries',
          :attributes => {:type => 'array'},
          :child => {
            :tag => 'query',
            :child => {
              :tag => 'id',
              :content => '4',
              :sibling => {
                :tag => 'name',
                :content => 'Public query for all projects'
              }
            }
          }
      end
    end
  end
  
  def credentials(user, password=nil)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)
  end
end
