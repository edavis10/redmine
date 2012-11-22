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

class GanttsControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :versions

    def test_gantt_should_work
      i2 = Issue.find(2)
      i2.update_attribute(:due_date, 1.month.from_now)
      get :show, :project_id => 1
      assert_response :success
      assert_template 'gantts/show'
      assert_not_nil assigns(:gantt)
      # Issue with start and due dates
      i = Issue.find(1)
      assert_not_nil i.due_date
      assert_select "div a.issue", /##{i.id}/
      # Issue with on a targeted version should not be in the events but loaded in the html
      i = Issue.find(2)
      assert_select "div a.issue", /##{i.id}/
    end

    def test_gantt_should_work_without_issue_due_dates
      Issue.update_all("due_date = NULL")
      get :show, :project_id => 1
      assert_response :success
      assert_template 'gantts/show'
      assert_not_nil assigns(:gantt)
    end

    def test_gantt_should_work_without_issue_and_version_due_dates
      Issue.update_all("due_date = NULL")
      Version.update_all("effective_date = NULL")
      get :show, :project_id => 1
      assert_response :success
      assert_template 'gantts/show'
      assert_not_nil assigns(:gantt)
    end

    def test_gantt_should_work_cross_project
      get :show
      assert_response :success
      assert_template 'gantts/show'
      assert_not_nil assigns(:gantt)
      assert_not_nil assigns(:gantt).query
      assert_nil assigns(:gantt).project
    end

    def test_gantt_should_not_disclose_private_projects
      get :show
      assert_response :success
      assert_template 'gantts/show'
      assert_tag 'a', :content => /eCookbook/
      # Root private project
      assert_no_tag 'a', {:content => /OnlineStore/}
      # Private children of a public project
      assert_no_tag 'a', :content => /Private child of eCookbook/
    end

    def test_gantt_should_export_to_pdf
      get :show, :project_id => 1, :format => 'pdf'
      assert_response :success
      assert_equal 'application/pdf', @response.content_type
      assert @response.body.starts_with?('%PDF')
      assert_not_nil assigns(:gantt)
    end

    def test_gantt_should_export_to_pdf_cross_project
      get :show, :format => 'pdf'
      assert_response :success
      assert_equal 'application/pdf', @response.content_type
      assert @response.body.starts_with?('%PDF')
      assert_not_nil assigns(:gantt)
    end

    if Object.const_defined?(:Magick)
      def test_gantt_should_export_to_png
        get :show, :project_id => 1, :format => 'png'
        assert_response :success
        assert_equal 'image/png', @response.content_type
      end
    end
end
