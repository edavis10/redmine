class ContextMenusController < ApplicationController
  helper :watchers
  helper :issues
  
  def issues
    @issues = Issue.visible.all(:conditions => {:id => params[:ids]}, :include => :project)
    
    if (@issues.size == 1)
      @issue = @issues.first
      @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    else
      @allowed_statuses = @issues.map do |i|
        i.new_statuses_allowed_to(User.current)
      end.inject do |memo,s|
        memo & s
      end
    end
    @projects = @issues.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1

    @can = {:edit => User.current.allowed_to?(:edit_issues, @projects),
            :log_time => (@project && User.current.allowed_to?(:log_time, @project)),
            :update => (User.current.allowed_to?(:edit_issues, @projects) || (User.current.allowed_to?(:change_status, @projects) && !@allowed_statuses.blank?)),
            :move => (@project && User.current.allowed_to?(:move_issues, @project)),
            :copy => (@issue && @project.trackers.include?(@issue.tracker) && User.current.allowed_to?(:add_issues, @project)),
            :delete => User.current.allowed_to?(:delete_issues, @projects)
            }
    if @project
      @assignables = @project.assignable_users
      @assignables << @issue.assigned_to if @issue && @issue.assigned_to && !@assignables.include?(@issue.assigned_to)
      @trackers = @project.trackers
    else
      #when multiple projects, we only keep the intersection of each set
      @assignables = @projects.map(&:assignable_users).inject{|memo,a| memo & a}
      @trackers = @projects.map(&:trackers).inject{|memo,t| memo & t}
    end
    
    @priorities = IssuePriority.all.reverse
    @statuses = IssueStatus.find(:all, :order => 'position')
    @back = back_url
    
    render :layout => false
  end

  def time_entries
    @time_entries = TimeEntry.all(
       :conditions => {:id => params[:ids]}, :include => :project)
    @projects = @time_entries.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
    @activities = TimeEntryActivity.shared.active
    @can = {:edit   => User.current.allowed_to?(:log_time, @projects),
            :update => User.current.allowed_to?(:log_time, @projects),
            :delete => User.current.allowed_to?(:log_time, @projects)
            }
    @back = back_url
    render :layout => false
  end  
end
