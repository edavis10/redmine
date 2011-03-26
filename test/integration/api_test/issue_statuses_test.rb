# Redmine - project management software
# Copyright (C) 2006-2010  Jean-Philippe Lang
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

class ApiTest::IssueStatusesTest < ActionController::IntegrationTest
  fixtures :issue_statuses

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/index.xml" do
    should 'display all issues' do
      get '/issue_statuses.xml'
    
      assert_tag :tag => 'issue_statuses',
        :attributes => { :type => 'array' },
        :children => { :count => 6 }
    end
  end

  context "GET /issue_statuses/:id" do
    context ":id.xml" do
      should "display new issue" do
        get '/issue_statuses/1.xml'
        
        assert_tag :tag => 'issue_status',
          :child => {
            :tag => 'name',
            :content => 'New',
          },
          :child => {
            :tag => 'id',
            :content => '1',
          }
      end
    end

    context ":name.xml" do
      should "display new issue" do
        get '/issue_statuses/New.xml'
        
        assert_tag :tag => 'issue_status',
          :child => {
            :tag => 'name',
            :content => 'New',
          },
          :child => {
            :tag => 'id',
            :content => '1',
          }
      end
    end
  end
    
end
