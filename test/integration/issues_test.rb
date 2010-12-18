# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

class IssuesTest < ActionController::IntegrationTest
  fixtures :projects, 
           :users,
           :roles,
           :members,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers

  # create an issue
  def test_add_issue
    log_user('jsmith', 'jsmith')
    get 'projects/1/issues/new', :tracker_id => '1'
    assert_response :success
    assert_template 'issues/new'
    
    post 'projects/1/issues', :tracker_id => "1",
                                 :issue => { :start_date => "2006-12-26", 
                                             :priority_id => "4", 
                                             :subject => "new test issue", 
                                             :category_id => "", 
                                             :description => "new issue", 
                                             :done_ratio => "0",
                                             :due_date => "",
                                             :assigned_to_id => "" },
                                 :custom_fields => {'2' => 'Value for field 2'}
    # find created issue
    issue = Issue.find_by_subject("new test issue")
    assert_kind_of Issue, issue

    # check redirection
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue
    follow_redirect!
    assert_equal issue, assigns(:issue)

    # check issue attributes    
    assert_equal 'jsmith', issue.author.login
    assert_equal 1, issue.project.id
    assert_equal 1, issue.status.id
  end

  # add then remove 2 attachments to an issue
  def test_issue_attachements
    log_user('jsmith', 'jsmith')
    set_tmp_attachments_directory

    put 'issues/1',
         :notes => 'Some notes',
         :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'This is an attachment'}}
    assert_redirected_to "/issues/1"
    
    # make sure attachment was saved
    attachment = Issue.find(1).attachments.find_by_filename("testfile.txt")
    assert_kind_of Attachment, attachment
    assert_equal Issue.find(1), attachment.container
    assert_equal 'This is an attachment', attachment.description
    # verify the size of the attachment stored in db
    #assert_equal file_data_1.length, attachment.filesize
    # verify that the attachment was written to disk
    assert File.exist?(attachment.diskfile)
    
    # remove the attachments
    Issue.find(1).attachments.each(&:destroy)
    assert_equal 0, Issue.find(1).attachments.length
  end
  
  def test_other_formats_links_on_get_index
    get '/projects/ecookbook/issues'
    
    %w(Atom PDF CSV).each do |format|
      assert_tag :a, :content => format,
                     :attributes => { :href => "/projects/ecookbook/issues.#{format.downcase}",
                                      :rel => 'nofollow' }
    end
  end
  
  def test_other_formats_links_on_post_index_without_project_id_in_url
    post '/issues', :project_id => 'ecookbook'
    
    %w(Atom PDF CSV).each do |format|
      assert_tag :a, :content => format,
                     :attributes => { :href => "/projects/ecookbook/issues.#{format.downcase}",
                                      :rel => 'nofollow' }
    end
  end
  
  def test_pagination_links_on_get_index
    Setting.per_page_options = '2'
    get '/projects/ecookbook/issues'
    
    assert_tag :a, :content => '2',
                   :attributes => { :href => '/projects/ecookbook/issues?page=2' }
    
  end
  
  def test_pagination_links_on_post_index_without_project_id_in_url
    Setting.per_page_options = '2'
    post '/issues', :project_id => 'ecookbook'
    
    assert_tag :a, :content => '2',
                   :attributes => { :href => '/projects/ecookbook/issues?page=2' }
    
  end
end
