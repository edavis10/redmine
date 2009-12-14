# Redmine - project management software
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

class WorkflowsController < ApplicationController
  before_filter :require_admin

  def index
    @workflow_counts = Workflow.count_by_tracker_and_role
  end
  
  def edit
    @role = Role.find_by_id(params[:role_id])
    @tracker = Tracker.find_by_id(params[:tracker_id])    
    
    if request.post?
      Workflow.destroy_all( ["role_id=? and tracker_id=?", @role.id, @tracker.id])
      (params[:issue_status] || []).each { |old, news| 
        news.each { |new| 
          @role.workflows.build(:tracker_id => @tracker.id, :old_status_id => old, :new_status_id => new) 
        }
      }
      if @role.save
        flash[:notice] = l(:notice_successful_update)
        redirect_to :action => 'edit', :role_id => @role, :tracker_id => @tracker
      end
    end
    @roles = Role.find(:all, :order => 'builtin, position')
    @trackers = Tracker.find(:all, :order => 'position')
    @statuses = IssueStatus.find(:all, :order => 'position')
  end
  
  def copy
    @trackers = Tracker.find(:all, :order => 'position')
    @roles = Role.find(:all, :order => 'builtin, position')
    
    @source_tracker = params[:source_tracker_id].blank? ? nil : Tracker.find_by_id(params[:source_tracker_id])
    @source_role = params[:source_role_id].blank? ? nil : Role.find_by_id(params[:source_role_id])
    
    @target_trackers = params[:target_tracker_ids].blank? ? nil : Tracker.find_all_by_id(params[:target_tracker_ids])
    @target_roles = params[:target_role_ids].blank? ? nil : Role.find_all_by_id(params[:target_role_ids])
     
    if request.post?
      if params[:source_tracker_id].blank? || params[:source_role_id].blank? || (@source_tracker.nil? && @source_role.nil?)
        flash.now[:error] = l(:error_workflow_copy_source)
      elsif @target_trackers.nil? || @target_roles.nil?
        flash.now[:error] = l(:error_workflow_copy_target)
      else
        Workflow.copy(@source_tracker, @source_role, @target_trackers, @target_roles)
        flash[:notice] = l(:notice_successful_update)
        redirect_to :action => 'copy', :source_tracker_id => @source_tracker, :source_role_id => @source_role
      end
    end
  end
end
