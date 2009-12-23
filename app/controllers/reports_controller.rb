# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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

class ReportsController < ApplicationController
  menu_item :issues
  before_filter :find_project, :authorize

  def issue_report
    @statuses = IssueStatus.find(:all, :order => 'position')
    
    case params[:detail]
    when "tracker"
      @field = "tracker_id"
      @rows = @project.trackers
      @data = issues_by_tracker
      @report_title = l(:field_tracker)
      render :template => "reports/issue_report_details"
    when "version"
      @field = "fixed_version_id"
      @rows = @project.shared_versions.sort
      @data = issues_by_version
      @report_title = l(:field_version)
      render :template => "reports/issue_report_details"
    when "priority"
      @field = "priority_id"
      @rows = IssuePriority.all
      @data = issues_by_priority
      @report_title = l(:field_priority)
      render :template => "reports/issue_report_details"   
    when "category"
      @field = "category_id"
      @rows = @project.issue_categories
      @data = issues_by_category
      @report_title = l(:field_category)
      render :template => "reports/issue_report_details"   
    when "assigned_to"
      @field = "assigned_to_id"
      @rows = @project.members.collect { |m| m.user }
      @data = issues_by_assigned_to
      @report_title = l(:field_assigned_to)
      render :template => "reports/issue_report_details"
    when "author"
      @field = "author_id"
      @rows = @project.members.collect { |m| m.user }
      @data = issues_by_author
      @report_title = l(:field_author)
      render :template => "reports/issue_report_details"  
    when "subproject"
      @field = "project_id"
      @rows = @project.descendants.active
      @data = issues_by_subproject
      @report_title = l(:field_subproject)
      render :template => "reports/issue_report_details"  
    else
      @trackers = @project.trackers
      @versions = @project.shared_versions.sort
      @priorities = IssuePriority.all
      @categories = @project.issue_categories
      @assignees = @project.members.collect { |m| m.user }
      @authors = @project.members.collect { |m| m.user }
      @subprojects = @project.descendants.active
      issues_by_tracker
      issues_by_version
      issues_by_priority
      issues_by_category
      issues_by_assigned_to
      issues_by_author
      issues_by_subproject
      
      render :template => "reports/issue_report"
    end
  end  
  
private
  # Find project of id params[:id]
  def find_project
    @project = Project.find(params[:id])		
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def issues_by_tracker
    @issues_by_tracker ||= 
        ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  t.id as tracker_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s, #{Tracker.table_name} t
                                                where 
                                                  i.status_id=s.id 
                                                  and i.tracker_id=t.id
                                                  and i.project_id=#{@project.id}
                                                group by s.id, s.is_closed, t.id")	
  end

  def issues_by_version
    @issues_by_version ||= 
        ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  v.id as fixed_version_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s, #{Version.table_name} v
                                                where 
                                                  i.status_id=s.id 
                                                  and i.fixed_version_id=v.id
                                                  and i.project_id=#{@project.id}
                                                group by s.id, s.is_closed, v.id")	
  end
  	
  def issues_by_priority    
    @issues_by_priority ||= 
      ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  p.id as priority_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s, #{IssuePriority.table_name} p
                                                where 
                                                  i.status_id=s.id 
                                                  and i.priority_id=p.id
                                                  and i.project_id=#{@project.id}
                                                group by s.id, s.is_closed, p.id")	
  end
	
  def issues_by_category   
    @issues_by_category ||= 
      ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  c.id as category_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s, #{IssueCategory.table_name} c
                                                where 
                                                  i.status_id=s.id 
                                                  and i.category_id=c.id
                                                  and i.project_id=#{@project.id}
                                                group by s.id, s.is_closed, c.id")	
  end
  
  def issues_by_assigned_to
    @issues_by_assigned_to ||= 
      ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  a.id as assigned_to_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s, #{User.table_name} a
                                                where 
                                                  i.status_id=s.id 
                                                  and i.assigned_to_id=a.id
                                                  and i.project_id=#{@project.id}
                                                group by s.id, s.is_closed, a.id")
  end
  
  def issues_by_author
    @issues_by_author ||= 
      ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  a.id as author_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s, #{User.table_name} a
                                                where 
                                                  i.status_id=s.id 
                                                  and i.author_id=a.id
                                                  and i.project_id=#{@project.id}
                                                group by s.id, s.is_closed, a.id")	
  end
  
  def issues_by_subproject
    @issues_by_subproject ||= 
      ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                  s.is_closed as closed, 
                                                  i.project_id as project_id,
                                                  count(i.id) as total 
                                                from 
                                                  #{Issue.table_name} i, #{IssueStatus.table_name} s
                                                where 
                                                  i.status_id=s.id 
                                                  and i.project_id IN (#{@project.descendants.active.collect{|p| p.id}.join(',')})
                                                group by s.id, s.is_closed, i.project_id") if @project.descendants.active.any?
    @issues_by_subproject ||= []
  end
end
