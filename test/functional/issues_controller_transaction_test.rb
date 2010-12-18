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

require File.expand_path('../../test_helper', __FILE__)
require 'issues_controller'

# Re-raise errors caught by the controller.
class IssuesController; def rescue_action(e) raise e end; end

class IssuesControllerTransactionTest < ActionController::TestCase
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

  self.use_transactional_fixtures = false
  
  def setup
    @controller = IssuesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end
  
  def test_put_update_stale_issue
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      assert_no_difference 'TimeEntry.count' do
        assert_no_difference 'Attachment.count' do
          put :update,
                :id => issue.id,
                :issue => {
                  :fixed_version_id => 4,
                  :lock_version => (issue.lock_version - 1)
                },
                :notes => '',
                :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}},
                :time_entry => { :hours => '2.5', :comments => '', :activity_id => TimeEntryActivity.first.id }
        end
      end
    end
    
    assert_response :success
    assert_template 'edit'
    assert_tag :tag => 'div', :attributes => { :id => 'errorExplanation' },
                              :content => /Data has been updated by another user/
  end
end
