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

class Version < ActiveRecord::Base
  after_update :update_issues_from_sharing_change
  belongs_to :project
  has_many :fixed_issues, :class_name => 'Issue', :foreign_key => 'fixed_version_id', :dependent => :nullify
  acts_as_customizable
  acts_as_attachable :view_permission => :view_files,
                     :delete_permission => :manage_files

  VERSION_STATUSES = %w(open locked closed)
  VERSION_SHARINGS = %w(none descendants hierarchy tree system)
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:project_id]
  validates_length_of :name, :maximum => 60
  validates_format_of :effective_date, :with => /^\d{4}-\d{2}-\d{2}$/, :message => :not_a_date, :allow_nil => true
  validates_inclusion_of :status, :in => VERSION_STATUSES
  validates_inclusion_of :sharing, :in => VERSION_SHARINGS

  named_scope :named, lambda {|arg| { :conditions => ["LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip]}}
  named_scope :open, :conditions => {:status => 'open'}
  named_scope :visible, lambda {|*args| { :include => :project,
                                          :conditions => Project.allowed_to_condition(args.first || User.current, :view_issues) } }

  # Returns true if +user+ or current user is allowed to view the version
  def visible?(user=User.current)
    user.allowed_to?(:view_issues, self.project)
  end
  
  def start_date
    @start_date ||= fixed_issues.minimum('start_date')
  end
  
  def due_date
    effective_date
  end
  
  # Returns the total estimated time for this version
  # (sum of leaves estimated_hours)
  def estimated_hours
    @estimated_hours ||= fixed_issues.leaves.sum(:estimated_hours).to_f
  end
  
  # Returns the total reported time for this version
  def spent_hours
    @spent_hours ||= TimeEntry.sum(:hours, :include => :issue, :conditions => ["#{Issue.table_name}.fixed_version_id = ?", id]).to_f
  end
  
  def closed?
    status == 'closed'
  end

  def open?
    status == 'open'
  end
  
  # Returns true if the version is completed: due date reached and no open issues
  def completed?
    effective_date && (effective_date <= Date.today) && (open_issues_count == 0)
  end

  def behind_schedule?
    if completed_pourcent == 100
      return false
    elsif due_date && start_date
      done_date = start_date + ((due_date - start_date+1)* completed_pourcent/100).floor
      return done_date <= Date.today
    else
      false # No issues so it's not late
    end
  end
  
  # Returns the completion percentage of this version based on the amount of open/closed issues
  # and the time spent on the open issues.
  def completed_pourcent
    if issues_count == 0
      0
    elsif open_issues_count == 0
      100
    else
      issues_progress(false) + issues_progress(true)
    end
  end
  
  # Returns the percentage of issues that have been marked as 'closed'.
  def closed_pourcent
    if issues_count == 0
      0
    else
      issues_progress(false)
    end
  end
  
  # Returns true if the version is overdue: due date reached and some open issues
  def overdue?
    effective_date && (effective_date < Date.today) && (open_issues_count > 0)
  end
  
  # Returns assigned issues count
  def issues_count
    @issue_count ||= fixed_issues.count
  end
  
  # Returns the total amount of open issues for this version.
  def open_issues_count
    @open_issues_count ||= Issue.count(:all, :conditions => ["fixed_version_id = ? AND is_closed = ?", self.id, false], :include => :status)
  end

  # Returns the total amount of closed issues for this version.
  def closed_issues_count
    @closed_issues_count ||= Issue.count(:all, :conditions => ["fixed_version_id = ? AND is_closed = ?", self.id, true], :include => :status)
  end
  
  def wiki_page
    if project.wiki && !wiki_page_title.blank?
      @wiki_page ||= project.wiki.find_page(wiki_page_title)
    end
    @wiki_page
  end
  
  def to_s; name end

  def to_s_with_project
    "#{project} - #{name}"
  end
  
  # Versions are sorted by effective_date and "Project Name - Version name"
  # Those with no effective_date are at the end, sorted by "Project Name - Version name"
  def <=>(version)
    if self.effective_date
      if version.effective_date
        if self.effective_date == version.effective_date
          "#{self.project.name} - #{self.name}" <=> "#{version.project.name} - #{version.name}"
        else
          self.effective_date <=> version.effective_date
        end
      else
        -1
      end
    else
      if version.effective_date
        1
      else
        "#{self.project.name} - #{self.name}" <=> "#{version.project.name} - #{version.name}"
      end
    end
  end
  
  # Returns the sharings that +user+ can set the version to
  def allowed_sharings(user = User.current)
    VERSION_SHARINGS.select do |s|
      if sharing == s
        true
      else
        case s
        when 'system'
          # Only admin users can set a systemwide sharing
          user.admin?
        when 'hierarchy', 'tree'
          # Only users allowed to manage versions of the root project can
          # set sharing to hierarchy or tree
          project.nil? || user.allowed_to?(:manage_versions, project.root)
        else
          true
        end
      end
    end
  end
  
  private

  # Update the issue's fixed versions. Used if a version's sharing changes.
  def update_issues_from_sharing_change
    if sharing_changed?
      if VERSION_SHARINGS.index(sharing_was).nil? ||
          VERSION_SHARINGS.index(sharing).nil? ||
          VERSION_SHARINGS.index(sharing_was) > VERSION_SHARINGS.index(sharing)
        Issue.update_versions_from_sharing_change self
      end
    end
  end
  
  # Returns the average estimated time of assigned issues
  # or 1 if no issue has an estimated time
  # Used to weigth unestimated issues in progress calculation
  def estimated_average
    if @estimated_average.nil?
      average = fixed_issues.average(:estimated_hours).to_f
      if average == 0
        average = 1
      end
      @estimated_average = average
    end
    @estimated_average
  end
  
  # Returns the total progress of open or closed issues.  The returned percentage takes into account
  # the amount of estimated time set for this version.
  #
  # Examples:
  # issues_progress(true)   => returns the progress percentage for open issues.
  # issues_progress(false)  => returns the progress percentage for closed issues.
  def issues_progress(open)
    @issues_progress ||= {}
    @issues_progress[open] ||= begin
      progress = 0
      if issues_count > 0
        ratio = open ? 'done_ratio' : 100
        
        done = fixed_issues.sum("COALESCE(estimated_hours, #{estimated_average}) * #{ratio}",
                                  :include => :status,
                                  :conditions => ["is_closed = ?", !open]).to_f
        progress = done / (estimated_average * issues_count)
      end
      progress
    end
  end
end
