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

class ReportsControllerTest < Redmine::ControllerTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :versions

  def test_get_issue_report
    get :issue_report, :params => {
        :id => 1
      }
    assert_response :success
  end

  def test_get_issue_report_details
    %w(tracker version priority category assigned_to author subproject).each do |detail|
      get :issue_report_details, :params => {
          :id => 1,
          :detail => detail
        }
      assert_response :success
    end
  end

  def test_get_issue_report_details_by_tracker_should_show_issue_count
    Issue.delete_all
    Issue.generate!(:tracker_id => 1)
    Issue.generate!(:tracker_id => 1)
    Issue.generate!(:tracker_id => 1, :status_id => 5)
    Issue.generate!(:tracker_id => 2)

    get :issue_report_details, :params => {
        :id => 1,
        :detail => 'tracker'
      }
    assert_select 'table.list tbody :nth-child(1)' do
      assert_select 'td', :text => 'Bug'
      assert_select ':nth-child(2)', :text => '2' # status:1
      assert_select ':nth-child(3)', :text => '-' # status:2
      assert_select ':nth-child(8)', :text => '2' # open
      assert_select ':nth-child(9)', :text => '1' # closed
      assert_select ':nth-child(10)', :text => '3' # total
    end
  end

  def test_get_issue_report_details_with_an_invalid_detail
    get :issue_report_details, :params => {
        :id => 1,
        :detail => 'invalid'
      }
    assert_response 404
  end
end
