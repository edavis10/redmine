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

require "#{File.dirname(__FILE__)}/../test_helper"

class IssuesApiTest < ActionController::IntegrationTest
  fixtures :projects,
    :users,
    :roles,
    :members,
    :member_roles,
    :issues,
    :issue_statuses,
    :versions,
    :trackers,
    :projects_trackers,
    :issue_categories,
    :enabled_modules,
    :enumerations,
    :attachments,
    :workflows,
    :custom_fields,
    :custom_values,
    :custom_fields_projects,
    :custom_fields_trackers,
    :time_entries,
    :journals,
    :journal_details,
    :queries

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/index.xml" do
    setup do
      get '/issues.xml'
    end

    should_respond_with :success
    should_respond_with_content_type 'application/xml'
  end

  context "/index.json" do
    setup do
      get '/issues.json'
    end

    should_respond_with :success
    should_respond_with_content_type 'application/json'

    should 'return a valid JSON string' do
      assert ActiveSupport::JSON.decode(response.body)
    end
  end

  context "/index.xml with filter" do
    setup do
      get '/issues.xml?status_id=5'
    end
    
    should_respond_with :success
    should_respond_with_content_type 'application/xml'
    should "show only issues with the status_id" do
      assert_tag :tag => 'issues',
                 :children => { :count => Issue.visible.count(:conditions => {:status_id => 5}), 
                                :only => { :tag => 'issue' } }
    end
  end

  context "/index.json with filter" do
    setup do
      get '/issues.json?status_id=5'
    end

    should_respond_with :success
    should_respond_with_content_type 'application/json'

    should 'return a valid JSON string' do
      assert ActiveSupport::JSON.decode(response.body)
    end

    should "show only issues with the status_id" do
      json = ActiveSupport::JSON.decode(response.body)
      status_ids_used = json.collect {|j| j['status_id'] }
      assert_equal 3, status_ids_used.length
      assert status_ids_used.all? {|id| id == 5 }
    end

  end

  context "/issues/1.xml" do
    setup do
      get '/issues/1.xml'
    end
    
    should_respond_with :success
    should_respond_with_content_type 'application/xml'
  end

  context "/issues/1.json" do
    setup do
      get '/issues/1.json'
    end
    
    should_respond_with :success
    should_respond_with_content_type 'application/json'

    should 'return a valid JSON string' do
      assert ActiveSupport::JSON.decode(response.body)
    end
  end

  context "POST /issues.xml" do
    setup do
      @issue_count = Issue.count
      @attributes = {:project_id => 1, :subject => 'API test', :tracker_id => 2, :status_id => 3}
      post '/issues.xml', {:issue => @attributes}, :authorization => credentials('jsmith')
    end

    should_respond_with :created
    should_respond_with_content_type 'application/xml'

    should "create an issue with the attributes" do
      assert_equal Issue.count, @issue_count + 1

      issue = Issue.first(:order => 'id DESC')
      @attributes.each do |attribute, value|
        assert_equal value, issue.send(attribute)
      end
    end
  end
  
  context "POST /issues.xml with failure" do
    setup do
      @attributes = {:project_id => 1}
      post '/issues.xml', {:issue => @attributes}, :authorization => credentials('jsmith')
    end

    should_respond_with :unprocessable_entity
    should_respond_with_content_type 'application/xml'

    should "have an errors tag" do
      assert_tag :errors, :child => {:tag => 'error', :content => "Subject can't be blank"}
    end
  end

  context "POST /issues.json" do
    setup do
      @issue_count = Issue.count
      @attributes = {:project_id => 1, :subject => 'API test', :tracker_id => 2, :status_id => 3}
      post '/issues.json', {:issue => @attributes}, :authorization => credentials('jsmith')
    end

    should_respond_with :created
    should_respond_with_content_type 'application/json'

    should "create an issue with the attributes" do
      assert_equal Issue.count, @issue_count + 1

      issue = Issue.first(:order => 'id DESC')
      @attributes.each do |attribute, value|
        assert_equal value, issue.send(attribute)
      end
    end
  end
  
  context "POST /issues.json with failure" do
    setup do
      @attributes = {:project_id => 1}
      post '/issues.json', {:issue => @attributes}, :authorization => credentials('jsmith')
    end

    should_respond_with :unprocessable_entity
    should_respond_with_content_type 'application/json'

    should "have an errors element" do
      json = ActiveSupport::JSON.decode(response.body)
      assert_equal "can't be blank", json.first['subject']
    end
  end

  context "PUT /issues/1.xml" do
    setup do
      @issue_count = Issue.count
      @journal_count = Journal.count
      @attributes = {:subject => 'API update', :notes => 'A new note'}

      put '/issues/1.xml', {:issue => @attributes}, :authorization => credentials('jsmith')
    end
    
    should_respond_with :ok
    should_respond_with_content_type 'application/xml'

    should "not create a new issue" do
      assert_equal Issue.count, @issue_count
    end

    should "create a new journal" do
      assert_equal Journal.count, @journal_count + 1
    end

    should "add the note to the journal" do
      journal = Journal.last
      assert_equal "A new note", journal.notes
    end

    should "update the issue" do
      issue = Issue.find(1)
      @attributes.each do |attribute, value|
        assert_equal value, issue.send(attribute) unless attribute == :notes
      end
    end
    
  end
  
  context "PUT /issues/1.xml with failed update" do
    setup do
      @attributes = {:subject => ''}
      @issue_count = Issue.count
      @journal_count = Journal.count

      put '/issues/1.xml', {:issue => @attributes}, :authorization => credentials('jsmith')
    end
    
    should_respond_with :unprocessable_entity
    should_respond_with_content_type 'application/xml'
  
    should "not create a new issue" do
      assert_equal Issue.count, @issue_count
    end

    should "not create a new journal" do
      assert_equal Journal.count, @journal_count
    end

    should "have an errors tag" do
      assert_tag :errors, :child => {:tag => 'error', :content => "Subject can't be blank"}
    end
  end

  context "PUT /issues/1.json" do
    setup do
      @issue_count = Issue.count
      @journal_count = Journal.count
      @attributes = {:subject => 'API update', :notes => 'A new note'}

      put '/issues/1.json', {:issue => @attributes}, :authorization => credentials('jsmith')
    end
    
    should_respond_with :ok
    should_respond_with_content_type 'application/json'

    should "not create a new issue" do
      assert_equal Issue.count, @issue_count
    end

    should "create a new journal" do
      assert_equal Journal.count, @journal_count + 1
    end

    should "add the note to the journal" do
      journal = Journal.last
      assert_equal "A new note", journal.notes
    end

    should "update the issue" do
      issue = Issue.find(1)
      @attributes.each do |attribute, value|
        assert_equal value, issue.send(attribute) unless attribute == :notes
      end
    end

  end
  
  context "PUT /issues/1.json with failed update" do
    setup do
      @attributes = {:subject => ''}
      @issue_count = Issue.count
      @journal_count = Journal.count

      put '/issues/1.json', {:issue => @attributes}, :authorization => credentials('jsmith')
    end
    
    should_respond_with :unprocessable_entity
    should_respond_with_content_type 'application/json'
  
    should "not create a new issue" do
      assert_equal Issue.count, @issue_count
    end

    should "not create a new journal" do
      assert_equal Journal.count, @journal_count
    end

    should "have an errors attribute" do
      json = ActiveSupport::JSON.decode(response.body)
      assert_equal "can't be blank", json.first['subject']
    end
  end

  context "DELETE /issues/1.xml" do
    setup do
      @issue_count = Issue.count
      delete '/issues/1.xml', {}, :authorization => credentials('jsmith')
    end

    should_respond_with :ok
    should_respond_with_content_type 'application/xml'

    should "delete the issue" do
      assert_equal Issue.count, @issue_count -1
      assert_nil Issue.find_by_id(1)
    end
  end

  context "DELETE /issues/1.json" do
    setup do
      @issue_count = Issue.count
      delete '/issues/1.json', {}, :authorization => credentials('jsmith')
    end

    should_respond_with :ok
    should_respond_with_content_type 'application/json'

    should "delete the issue" do
      assert_equal Issue.count, @issue_count -1
      assert_nil Issue.find_by_id(1)
    end
  end

  def credentials(user, password=nil)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)
  end
end
