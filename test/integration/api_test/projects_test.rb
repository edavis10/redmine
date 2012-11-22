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

class ApiTest::ProjectsTest < ActionController::IntegrationTest
  fixtures :projects, :versions, :users, :roles, :members, :member_roles, :issues, :journals, :journal_details,
           :trackers, :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :boards, :messages,
           :attachments, :custom_fields, :custom_values, :time_entries, :issue_categories

  def setup
    Setting.rest_api_enabled = '1'
    set_tmp_attachments_directory
  end

  context "GET /projects" do
    context ".xml" do
      should "return projects" do
        get '/projects.xml'
        assert_response :success
        assert_equal 'application/xml', @response.content_type

        assert_tag :tag => 'projects',
          :child => {:tag => 'project', :child => {:tag => 'id', :content => '1'}}
      end
    end

    context ".json" do
      should "return projects" do
        get '/projects.json'
        assert_response :success
        assert_equal 'application/json', @response.content_type

        json = ActiveSupport::JSON.decode(response.body)
        assert_kind_of Hash, json
        assert_kind_of Array, json['projects']
        assert_kind_of Hash, json['projects'].first
        assert json['projects'].first.has_key?('id')
      end
    end
  end

  context "GET /projects/:id" do
    context ".xml" do
      # TODO: A private project is needed because should_allow_api_authentication
      # actually tests that authentication is *required*, not just allowed
      should_allow_api_authentication(:get, "/projects/2.xml")

      should "return requested project" do
        get '/projects/1.xml'
        assert_response :success
        assert_equal 'application/xml', @response.content_type

        assert_tag :tag => 'project',
          :child => {:tag => 'id', :content => '1'}
        assert_tag :tag => 'custom_field',
          :attributes => {:name => 'Development status'}, :content => 'Stable'

        assert_no_tag 'trackers'
        assert_no_tag 'issue_categories'
      end

      context "with hidden custom fields" do
        setup do
          ProjectCustomField.find_by_name('Development status').update_attribute :visible, false
        end

        should "not display hidden custom fields" do
          get '/projects/1.xml'
          assert_response :success
          assert_equal 'application/xml', @response.content_type

          assert_no_tag 'custom_field',
            :attributes => {:name => 'Development status'}
        end
      end

      should "return categories with include=issue_categories" do
        get '/projects/1.xml?include=issue_categories'
        assert_response :success
        assert_equal 'application/xml', @response.content_type

        assert_tag 'issue_categories',
          :attributes => {:type => 'array'},
          :child => {
            :tag => 'issue_category',
            :attributes => {
              :id => '2',
              :name => 'Recipes'
            }
          }
      end

      should "return trackers with include=trackers" do
        get '/projects/1.xml?include=trackers'
        assert_response :success
        assert_equal 'application/xml', @response.content_type

        assert_tag 'trackers',
          :attributes => {:type => 'array'},
          :child => {
            :tag => 'tracker',
            :attributes => {
              :id => '2',
              :name => 'Feature request'
            }
          }
      end
    end

    context ".json" do
      should_allow_api_authentication(:get, "/projects/2.json")

      should "return requested project" do
        get '/projects/1.json'

        json = ActiveSupport::JSON.decode(response.body)
        assert_kind_of Hash, json
        assert_kind_of Hash, json['project']
        assert_equal 1, json['project']['id']
      end
    end
  end

  context "POST /projects" do
    context "with valid parameters" do
      setup do
        Setting.default_projects_modules = ['issue_tracking', 'repository']
        @parameters = {:project => {:name => 'API test', :identifier => 'api-test'}}
      end

      context ".xml" do
        should_allow_api_authentication(:post,
                                        '/projects.xml',
                                        {:project => {:name => 'API test', :identifier => 'api-test'}},
                                        {:success_code => :created})


        should "create a project with the attributes" do
          assert_difference('Project.count') do
            post '/projects.xml', @parameters, credentials('admin')
          end

          project = Project.first(:order => 'id DESC')
          assert_equal 'API test', project.name
          assert_equal 'api-test', project.identifier
          assert_equal ['issue_tracking', 'repository'], project.enabled_module_names.sort
          assert_equal Tracker.all.size, project.trackers.size

          assert_response :created
          assert_equal 'application/xml', @response.content_type
          assert_tag 'project', :child => {:tag => 'id', :content => project.id.to_s}
        end

        should "accept enabled_module_names attribute" do
          @parameters[:project].merge!({:enabled_module_names => ['issue_tracking', 'news', 'time_tracking']})

          assert_difference('Project.count') do
            post '/projects.xml', @parameters, credentials('admin')
          end

          project = Project.first(:order => 'id DESC')
          assert_equal ['issue_tracking', 'news', 'time_tracking'], project.enabled_module_names.sort
        end

        should "accept tracker_ids attribute" do
          @parameters[:project].merge!({:tracker_ids => [1, 3]})

          assert_difference('Project.count') do
            post '/projects.xml', @parameters, credentials('admin')
          end

          project = Project.first(:order => 'id DESC')
          assert_equal [1, 3], project.trackers.map(&:id).sort
        end
      end
    end

    context "with invalid parameters" do
      setup do
        @parameters = {:project => {:name => 'API test'}}
      end

      context ".xml" do
        should "return errors" do
          assert_no_difference('Project.count') do
            post '/projects.xml', @parameters, credentials('admin')
          end

          assert_response :unprocessable_entity
          assert_equal 'application/xml', @response.content_type
          assert_tag 'errors', :child => {:tag => 'error', :content => "Identifier can't be blank"}
        end
      end
    end
  end

  context "PUT /projects/:id" do
    context "with valid parameters" do
      setup do
        @parameters = {:project => {:name => 'API update'}}
      end

      context ".xml" do
        should_allow_api_authentication(:put,
                                        '/projects/2.xml',
                                        {:project => {:name => 'API update'}},
                                        {:success_code => :ok})

        should "update the project" do
          assert_no_difference 'Project.count' do
            put '/projects/2.xml', @parameters, credentials('jsmith')
          end
          assert_response :ok
          assert_equal '', @response.body
          assert_equal 'application/xml', @response.content_type
          project = Project.find(2)
          assert_equal 'API update', project.name
        end

        should "accept enabled_module_names attribute" do
          @parameters[:project].merge!({:enabled_module_names => ['issue_tracking', 'news', 'time_tracking']})

          assert_no_difference 'Project.count' do
            put '/projects/2.xml', @parameters, credentials('admin')
          end
          assert_response :ok
          assert_equal '', @response.body
          project = Project.find(2)
          assert_equal ['issue_tracking', 'news', 'time_tracking'], project.enabled_module_names.sort
        end

        should "accept tracker_ids attribute" do
          @parameters[:project].merge!({:tracker_ids => [1, 3]})

          assert_no_difference 'Project.count' do
            put '/projects/2.xml', @parameters, credentials('admin')
          end
          assert_response :ok
          assert_equal '', @response.body
          project = Project.find(2)
          assert_equal [1, 3], project.trackers.map(&:id).sort
        end
      end
    end

    context "with invalid parameters" do
      setup do
        @parameters = {:project => {:name => ''}}
      end

      context ".xml" do
        should "return errors" do
          assert_no_difference('Project.count') do
            put '/projects/2.xml', @parameters, credentials('admin')
          end

          assert_response :unprocessable_entity
          assert_equal 'application/xml', @response.content_type
          assert_tag 'errors', :child => {:tag => 'error', :content => "Name can't be blank"}
        end
      end
    end
  end

  context "DELETE /projects/:id" do
    context ".xml" do
      should_allow_api_authentication(:delete,
                                      '/projects/2.xml',
                                      {},
                                      {:success_code => :ok})

      should "delete the project" do
        assert_difference('Project.count',-1) do
          delete '/projects/2.xml', {}, credentials('admin')
        end
        assert_response :ok
        assert_equal '', @response.body
        assert_nil Project.find_by_id(2)
      end
    end
  end
end
