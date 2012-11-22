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

class TimeEntry < ActiveRecord::Base
  include Redmine::SafeAttributes
  # could have used polymorphic association
  # project association here allows easy loading of time entries at project level with one database trip
  belongs_to :project
  belongs_to :issue
  belongs_to :user
  belongs_to :activity, :class_name => 'TimeEntryActivity', :foreign_key => 'activity_id'

  attr_protected :project_id, :user_id, :tyear, :tmonth, :tweek

  acts_as_customizable
  acts_as_event :title => Proc.new {|o| "#{l_hours(o.hours)} (#{(o.issue || o.project).event_title})"},
                :url => Proc.new {|o| {:controller => 'timelog', :action => 'index', :project_id => o.project, :issue_id => o.issue}},
                :author => :user,
                :description => :comments

  acts_as_activity_provider :timestamp => "#{table_name}.created_on",
                            :author_key => :user_id,
                            :find_options => {:include => :project}

  validates_presence_of :user_id, :activity_id, :project_id, :hours, :spent_on
  validates_numericality_of :hours, :allow_nil => true, :message => :invalid
  validates_length_of :comments, :maximum => 255, :allow_nil => true
  before_validation :set_project_if_nil
  validate :validate_time_entry

  scope :visible, lambda {|*args| {
    :include => :project,
    :conditions => Project.allowed_to_condition(args.shift || User.current, :view_time_entries, *args)
  }}
  scope :on_issue, lambda {|issue| {
    :include => :issue,
    :conditions => "#{Issue.table_name}.root_id = #{issue.root_id} AND #{Issue.table_name}.lft >= #{issue.lft} AND #{Issue.table_name}.rgt <= #{issue.rgt}"
  }}
  scope :on_project, lambda {|project, include_subprojects| {
    :include => :project,
    :conditions => project.project_condition(include_subprojects)
  }}
  scope :spent_between, lambda {|from, to|
    if from && to
     {:conditions => ["#{TimeEntry.table_name}.spent_on BETWEEN ? AND ?", from, to]}
    elsif from
     {:conditions => ["#{TimeEntry.table_name}.spent_on >= ?", from]}
    elsif to
     {:conditions => ["#{TimeEntry.table_name}.spent_on <= ?", to]}
    else
     {}
    end
  }

  safe_attributes 'hours', 'comments', 'issue_id', 'activity_id', 'spent_on', 'custom_field_values', 'custom_fields'

  def initialize(attributes=nil, *args)
    super
    if new_record? && self.activity.nil?
      if default_activity = TimeEntryActivity.default
        self.activity_id = default_activity.id
      end
      self.hours = nil if hours == 0
    end
  end

  def set_project_if_nil
    self.project = issue.project if issue && project.nil?
  end

  def validate_time_entry
    errors.add :hours, :invalid if hours && (hours < 0 || hours >= 1000)
    errors.add :project_id, :invalid if project.nil?
    errors.add :issue_id, :invalid if (issue_id && !issue) || (issue && project!=issue.project)
  end

  def hours=(h)
    write_attribute :hours, (h.is_a?(String) ? (h.to_hours || h) : h)
  end

  def hours
    h = read_attribute(:hours)
    if h.is_a?(Float)
      h.round(2)
    else
      h
    end
  end

  # tyear, tmonth, tweek assigned where setting spent_on attributes
  # these attributes make time aggregations easier
  def spent_on=(date)
    super
    if spent_on.is_a?(Time)
      self.spent_on = spent_on.to_date
    end
    self.tyear = spent_on ? spent_on.year : nil
    self.tmonth = spent_on ? spent_on.month : nil
    self.tweek = spent_on ? Date.civil(spent_on.year, spent_on.month, spent_on.day).cweek : nil
  end

  # Returns true if the time entry can be edited by usr, otherwise false
  def editable_by?(usr)
    (usr == user && usr.allowed_to?(:edit_own_time_entries, project)) || usr.allowed_to?(:edit_time_entries, project)
  end
end
