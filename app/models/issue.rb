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

class Issue < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :project
  belongs_to :tracker
  belongs_to :status, :class_name => 'IssueStatus', :foreign_key => 'status_id'
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :assigned_to, :class_name => 'Principal', :foreign_key => 'assigned_to_id'
  belongs_to :fixed_version, :class_name => 'Version', :foreign_key => 'fixed_version_id'
  belongs_to :priority, :class_name => 'IssuePriority', :foreign_key => 'priority_id'
  belongs_to :category, :class_name => 'IssueCategory', :foreign_key => 'category_id'

  has_many :journals, :as => :journalized, :dependent => :destroy
  has_many :time_entries, :dependent => :delete_all
  has_and_belongs_to_many :changesets, :order => "#{Changeset.table_name}.committed_on ASC, #{Changeset.table_name}.id ASC"

  has_many :relations_from, :class_name => 'IssueRelation', :foreign_key => 'issue_from_id', :dependent => :delete_all
  has_many :relations_to, :class_name => 'IssueRelation', :foreign_key => 'issue_to_id', :dependent => :delete_all

  acts_as_nested_set :scope => 'root_id', :dependent => :destroy
  acts_as_attachable :after_add => :attachment_added, :after_remove => :attachment_removed
  acts_as_customizable
  acts_as_watchable
  acts_as_searchable :columns => ['subject', "#{table_name}.description", "#{Journal.table_name}.notes"],
                     :include => [:project, :journals],
                     # sort by id so that limited eager loading doesn't break with postgresql
                     :order_column => "#{table_name}.id"
  acts_as_event :title => Proc.new {|o| "#{o.tracker.name} ##{o.id} (#{o.status}): #{o.subject}"},
                :url => Proc.new {|o| {:controller => 'issues', :action => 'show', :id => o.id}},
                :type => Proc.new {|o| 'issue' + (o.closed? ? ' closed' : '') }

  acts_as_activity_provider :find_options => {:include => [:project, :author, :tracker]},
                            :author_key => :author_id

  DONE_RATIO_OPTIONS = %w(issue_field issue_status)

  attr_reader :current_journal

  validates_presence_of :subject, :priority, :project, :tracker, :author, :status

  validates_length_of :subject, :maximum => 255
  validates_inclusion_of :done_ratio, :in => 0..100
  validates_numericality_of :estimated_hours, :allow_nil => true
  validate :validate_issue, :validate_required_fields

  scope :visible,
        lambda {|*args| { :include => :project,
                          :conditions => Issue.visible_condition(args.shift || User.current, *args) } }

  scope :open, lambda {|*args|
    is_closed = args.size > 0 ? !args.first : false
    {:conditions => ["#{IssueStatus.table_name}.is_closed = ?", is_closed], :include => :status}
  }

  scope :recently_updated, :order => "#{Issue.table_name}.updated_on DESC"
  scope :on_active_project, :include => [:status, :project, :tracker],
                            :conditions => ["#{Project.table_name}.status=#{Project::STATUS_ACTIVE}"]

  before_create :default_assign
  before_save :close_duplicates, :update_done_ratio_from_issue_status, :force_updated_on_change
  after_save {|issue| issue.send :after_project_change if !issue.id_changed? && issue.project_id_changed?} 
  after_save :reschedule_following_issues, :update_nested_set_attributes, :update_parent_attributes, :create_journal
  # Should be after_create but would be called before previous after_save callbacks
  after_save :after_create_from_copy
  after_destroy :update_parent_attributes

  # Returns a SQL conditions string used to find all issues visible by the specified user
  def self.visible_condition(user, options={})
    Project.allowed_to_condition(user, :view_issues, options) do |role, user|
      if user.logged?
        case role.issues_visibility
        when 'all'
          nil
        when 'default'
          user_ids = [user.id] + user.groups.map(&:id)
          "(#{table_name}.is_private = #{connection.quoted_false} OR #{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
        when 'own'
          user_ids = [user.id] + user.groups.map(&:id)
          "(#{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
        else
          '1=0'
        end
      else
        "(#{table_name}.is_private = #{connection.quoted_false})"
      end
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_issues, self.project) do |role, user|
      if user.logged?
        case role.issues_visibility
        when 'all'
          true
        when 'default'
          !self.is_private? || (self.author == user || user.is_or_belongs_to?(assigned_to))
        when 'own'
          self.author == user || user.is_or_belongs_to?(assigned_to)
        else
          false
        end
      else
        !self.is_private?
      end
    end
  end

  def initialize(attributes=nil, *args)
    super
    if new_record?
      # set default values for new records only
      self.status ||= IssueStatus.default
      self.priority ||= IssuePriority.default
      self.watcher_user_ids = []
    end
  end

  # AR#Persistence#destroy would raise and RecordNotFound exception
  # if the issue was already deleted or updated (non matching lock_version).
  # This is a problem when bulk deleting issues or deleting a project
  # (because an issue may already be deleted if its parent was deleted
  # first).
  # The issue is reloaded by the nested_set before being deleted so
  # the lock_version condition should not be an issue but we handle it.
  def destroy
    super
  rescue ActiveRecord::RecordNotFound
    # Stale or already deleted
    begin
      reload
    rescue ActiveRecord::RecordNotFound
      # The issue was actually already deleted
      @destroyed = true
      return freeze
    end
    # The issue was stale, retry to destroy
    super
  end

  def reload(*args)
    @workflow_rule_by_attribute = nil
    @assignable_versions = nil
    super
  end

  # Overrides Redmine::Acts::Customizable::InstanceMethods#available_custom_fields
  def available_custom_fields
    (project && tracker) ? (project.all_issue_custom_fields & tracker.custom_fields.all) : []
  end

  # Copies attributes from another issue, arg can be an id or an Issue
  def copy_from(arg, options={})
    issue = arg.is_a?(Issue) ? arg : Issue.visible.find(arg)
    self.attributes = issue.attributes.dup.except("id", "root_id", "parent_id", "lft", "rgt", "created_on", "updated_on")
    self.custom_field_values = issue.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
    self.status = issue.status
    self.author = User.current
    unless options[:attachments] == false
      self.attachments = issue.attachments.map do |attachement| 
        attachement.copy(:container => self)
      end
    end
    @copied_from = issue
    @copy_options = options
    self
  end

  # Returns an unsaved copy of the issue
  def copy(attributes=nil, copy_options={})
    copy = self.class.new.copy_from(self, copy_options)
    copy.attributes = attributes if attributes
    copy
  end

  # Returns true if the issue is a copy
  def copy?
    @copied_from.present?
  end

  # Moves/copies an issue to a new project and tracker
  # Returns the moved/copied issue on success, false on failure
  def move_to_project(new_project, new_tracker=nil, options={})
    ActiveSupport::Deprecation.warn "Issue#move_to_project is deprecated, use #project= instead."

    if options[:copy]
      issue = self.copy
    else
      issue = self
    end

    issue.init_journal(User.current, options[:notes])

    # Preserve previous behaviour
    # #move_to_project doesn't change tracker automatically
    issue.send :project=, new_project, true
    if new_tracker
      issue.tracker = new_tracker
    end
    # Allow bulk setting of attributes on the issue
    if options[:attributes]
      issue.attributes = options[:attributes]
    end

    issue.save ? issue : false
  end

  def status_id=(sid)
    self.status = nil
    result = write_attribute(:status_id, sid)
    @workflow_rule_by_attribute = nil
    result
  end

  def priority_id=(pid)
    self.priority = nil
    write_attribute(:priority_id, pid)
  end

  def category_id=(cid)
    self.category = nil
    write_attribute(:category_id, cid)
  end

  def fixed_version_id=(vid)
    self.fixed_version = nil
    write_attribute(:fixed_version_id, vid)
  end

  def tracker_id=(tid)
    self.tracker = nil
    result = write_attribute(:tracker_id, tid)
    @custom_field_values = nil
    @workflow_rule_by_attribute = nil
    result
  end

  def project_id=(project_id)
    if project_id.to_s != self.project_id.to_s
      self.project = (project_id.present? ? Project.find_by_id(project_id) : nil)
    end
  end

  def project=(project, keep_tracker=false)
    project_was = self.project
    write_attribute(:project_id, project ? project.id : nil)
    association_instance_set('project', project)
    if project_was && project && project_was != project
      @assignable_versions = nil

      unless keep_tracker || project.trackers.include?(tracker)
        self.tracker = project.trackers.first
      end
      # Reassign to the category with same name if any
      if category
        self.category = project.issue_categories.find_by_name(category.name)
      end
      # Keep the fixed_version if it's still valid in the new_project
      if fixed_version && fixed_version.project != project && !project.shared_versions.include?(fixed_version)
        self.fixed_version = nil
      end
      if parent && parent.project_id != project_id
        self.parent_issue_id = nil
      end
      @custom_field_values = nil
    end
  end

  def description=(arg)
    if arg.is_a?(String)
      arg = arg.gsub(/(\r\n|\n|\r)/, "\r\n")
    end
    write_attribute(:description, arg)
  end

  # Overrides assign_attributes so that project and tracker get assigned first
  def assign_attributes_with_project_and_tracker_first(new_attributes, *args)
    return if new_attributes.nil?
    attrs = new_attributes.dup
    attrs.stringify_keys!

    %w(project project_id tracker tracker_id).each do |attr|
      if attrs.has_key?(attr)
        send "#{attr}=", attrs.delete(attr)
      end
    end
    send :assign_attributes_without_project_and_tracker_first, attrs, *args
  end
  # Do not redefine alias chain on reload (see #4838)
  alias_method_chain(:assign_attributes, :project_and_tracker_first) unless method_defined?(:assign_attributes_without_project_and_tracker_first)

  def estimated_hours=(h)
    write_attribute :estimated_hours, (h.is_a?(String) ? h.to_hours : h)
  end

  safe_attributes 'project_id',
    :if => lambda {|issue, user|
      if issue.new_record?
        issue.copy?
      elsif user.allowed_to?(:move_issues, issue.project)
        projects = Issue.allowed_target_projects_on_move(user)
        projects.include?(issue.project) && projects.size > 1
      end
    }

  safe_attributes 'tracker_id',
    'status_id',
    'category_id',
    'assigned_to_id',
    'priority_id',
    'fixed_version_id',
    'subject',
    'description',
    'start_date',
    'due_date',
    'done_ratio',
    'estimated_hours',
    'custom_field_values',
    'custom_fields',
    'lock_version',
    :if => lambda {|issue, user| issue.new_record? || user.allowed_to?(:edit_issues, issue.project) }

  safe_attributes 'status_id',
    'assigned_to_id',
    'fixed_version_id',
    'done_ratio',
    'lock_version',
    :if => lambda {|issue, user| issue.new_statuses_allowed_to(user).any? }

  safe_attributes 'watcher_user_ids',
    :if => lambda {|issue, user| issue.new_record? && user.allowed_to?(:add_issue_watchers, issue.project)} 

  safe_attributes 'is_private',
    :if => lambda {|issue, user|
      user.allowed_to?(:set_issues_private, issue.project) ||
        (issue.author == user && user.allowed_to?(:set_own_issues_private, issue.project))
    }

  safe_attributes 'parent_issue_id',
    :if => lambda {|issue, user| (issue.new_record? || user.allowed_to?(:edit_issues, issue.project)) &&
      user.allowed_to?(:manage_subtasks, issue.project)}

  def safe_attribute_names(user=nil)
    names = super
    names -= disabled_core_fields
    names -= read_only_attribute_names(user)
    names
  end

  # Safely sets attributes
  # Should be called from controllers instead of #attributes=
  # attr_accessible is too rough because we still want things like
  # Issue.new(:project => foo) to work
  def safe_attributes=(attrs, user=User.current)
    return unless attrs.is_a?(Hash)

    attrs = attrs.dup

    # Project and Tracker must be set before since new_statuses_allowed_to depends on it.
    if (p = attrs.delete('project_id')) && safe_attribute?('project_id')
      if allowed_target_projects(user).collect(&:id).include?(p.to_i)
        self.project_id = p
      end
    end

    if (t = attrs.delete('tracker_id')) && safe_attribute?('tracker_id')
      self.tracker_id = t
    end

    if (s = attrs.delete('status_id')) && safe_attribute?('status_id')
      if new_statuses_allowed_to(user).collect(&:id).include?(s.to_i)
        self.status_id = s
      end
    end

    attrs = delete_unsafe_attributes(attrs, user)
    return if attrs.empty?

    unless leaf?
      attrs.reject! {|k,v| %w(priority_id done_ratio start_date due_date estimated_hours).include?(k)}
    end

    if attrs['parent_issue_id'].present?
      attrs.delete('parent_issue_id') unless Issue.visible(user).exists?(attrs['parent_issue_id'].to_i)
    end

    if attrs['custom_field_values'].present?
      attrs['custom_field_values'] = attrs['custom_field_values'].reject {|k, v| read_only_attribute_names(user).include? k.to_s}
    end

    if attrs['custom_fields'].present?
      attrs['custom_fields'] = attrs['custom_fields'].reject {|c| read_only_attribute_names(user).include? c['id'].to_s}
    end

    # mass-assignment security bypass
    assign_attributes attrs, :without_protection => true
  end

  def disabled_core_fields
    tracker ? tracker.disabled_core_fields : []
  end

  # Returns the custom_field_values that can be edited by the given user
  def editable_custom_field_values(user=nil)
    custom_field_values.reject do |value|
      read_only_attribute_names(user).include?(value.custom_field_id.to_s)
    end
  end

  # Returns the names of attributes that are read-only for user or the current user
  # For users with multiple roles, the read-only fields are the intersection of
  # read-only fields of each role
  # The result is an array of strings where sustom fields are represented with their ids
  #
  # Examples:
  #   issue.read_only_attribute_names # => ['due_date', '2']
  #   issue.read_only_attribute_names(user) # => []
  def read_only_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'readonly'}.keys
  end

  # Returns the names of required attributes for user or the current user
  # For users with multiple roles, the required fields are the intersection of
  # required fields of each role
  # The result is an array of strings where sustom fields are represented with their ids
  #
  # Examples:
  #   issue.required_attribute_names # => ['due_date', '2']
  #   issue.required_attribute_names(user) # => []
  def required_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'required'}.keys
  end

  # Returns true if the attribute is required for user
  def required_attribute?(name, user=nil)
    required_attribute_names(user).include?(name.to_s)
  end

  # Returns a hash of the workflow rule by attribute for the given user
  #
  # Examples:
  #   issue.workflow_rule_by_attribute # => {'due_date' => 'required', 'start_date' => 'readonly'}
  def workflow_rule_by_attribute(user=nil)
    return @workflow_rule_by_attribute if @workflow_rule_by_attribute && user.nil?

    user_real = user || User.current
    roles = user_real.admin ? Role.all : user_real.roles_for_project(project)
    return {} if roles.empty?

    result = {}
    workflow_permissions = WorkflowPermission.where(:tracker_id => tracker_id, :old_status_id => status_id, :role_id => roles.map(&:id)).all
    if workflow_permissions.any?
      workflow_rules = workflow_permissions.inject({}) do |h, wp|
        h[wp.field_name] ||= []
        h[wp.field_name] << wp.rule
        h
      end
      workflow_rules.each do |attr, rules|
        next if rules.size < roles.size
        uniq_rules = rules.uniq
        if uniq_rules.size == 1
          result[attr] = uniq_rules.first
        else
          result[attr] = 'required'
        end
      end
    end
    @workflow_rule_by_attribute = result if user.nil?
    result
  end
  private :workflow_rule_by_attribute

  def done_ratio
    if Issue.use_status_for_done_ratio? && status && status.default_done_ratio
      status.default_done_ratio
    else
      read_attribute(:done_ratio)
    end
  end

  def self.use_status_for_done_ratio?
    Setting.issue_done_ratio == 'issue_status'
  end

  def self.use_field_for_done_ratio?
    Setting.issue_done_ratio == 'issue_field'
  end

  def validate_issue
    if self.due_date.nil? && @attributes['due_date'] && !@attributes['due_date'].empty?
      errors.add :due_date, :not_a_date
    end

    if self.due_date and self.start_date and self.due_date < self.start_date
      errors.add :due_date, :greater_than_start_date
    end

    if start_date && soonest_start && start_date < soonest_start
      errors.add :start_date, :invalid
    end

    if fixed_version
      if !assignable_versions.include?(fixed_version)
        errors.add :fixed_version_id, :inclusion
      elsif reopened? && fixed_version.closed?
        errors.add :base, I18n.t(:error_can_not_reopen_issue_on_closed_version)
      end
    end

    # Checks that the issue can not be added/moved to a disabled tracker
    if project && (tracker_id_changed? || project_id_changed?)
      unless project.trackers.include?(tracker)
        errors.add :tracker_id, :inclusion
      end
    end

    # Checks parent issue assignment
    if @parent_issue
      if @parent_issue.project_id != project_id
        errors.add :parent_issue_id, :not_same_project
      elsif !new_record?
        # moving an existing issue
        if @parent_issue.root_id != root_id
          # we can always move to another tree
        elsif move_possible?(@parent_issue)
          # move accepted inside tree
        else
          errors.add :parent_issue_id, :not_a_valid_parent
        end
      end
    end
  end

  # Validates the issue against additional workflow requirements
  def validate_required_fields
    user = new_record? ? author : current_journal.try(:user)

    required_attribute_names(user).each do |attribute|
      if attribute =~ /^\d+$/
        attribute = attribute.to_i
        v = custom_field_values.detect {|v| v.custom_field_id == attribute }
        if v && v.value.blank?
          errors.add :base, v.custom_field.name + ' ' + l('activerecord.errors.messages.blank')
        end
      else
        if respond_to?(attribute) && send(attribute).blank?
          errors.add attribute, :blank
        end
      end
    end
  end

  # Set the done_ratio using the status if that setting is set.  This will keep the done_ratios
  # even if the user turns off the setting later
  def update_done_ratio_from_issue_status
    if Issue.use_status_for_done_ratio? && status && status.default_done_ratio
      self.done_ratio = status.default_done_ratio
    end
  end

  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)
    if new_record?
      @current_journal.notify = false
    else
      @attributes_before_change = attributes.dup
      @custom_values_before_change = {}
      self.custom_field_values.each {|c| @custom_values_before_change.store c.custom_field_id, c.value }
    end
    @current_journal
  end

  # Returns the id of the last journal or nil
  def last_journal_id
    if new_record?
      nil
    else
      journals.maximum(:id)
    end
  end

  # Returns a scope for journals that have an id greater than journal_id
  def journals_after(journal_id)
    scope = journals.reorder("#{Journal.table_name}.id ASC")
    if journal_id.present?
      scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
    end
    scope
  end

  # Return true if the issue is closed, otherwise false
  def closed?
    self.status.is_closed?
  end

  # Return true if the issue is being reopened
  def reopened?
    if !new_record? && status_id_changed?
      status_was = IssueStatus.find_by_id(status_id_was)
      status_new = IssueStatus.find_by_id(status_id)
      if status_was && status_new && status_was.is_closed? && !status_new.is_closed?
        return true
      end
    end
    false
  end

  # Return true if the issue is being closed
  def closing?
    if !new_record? && status_id_changed?
      status_was = IssueStatus.find_by_id(status_id_was)
      status_new = IssueStatus.find_by_id(status_id)
      if status_was && status_new && !status_was.is_closed? && status_new.is_closed?
        return true
      end
    end
    false
  end

  # Returns true if the issue is overdue
  def overdue?
    !due_date.nil? && (due_date < Date.today) && !status.is_closed?
  end

  # Is the amount of work done less than it should for the due date
  def behind_schedule?
    return false if start_date.nil? || due_date.nil?
    done_date = start_date + ((due_date - start_date+1)* done_ratio/100).floor
    return done_date <= Date.today
  end

  # Does this issue have children?
  def children?
    !leaf?
  end

  # Users the issue can be assigned to
  def assignable_users
    users = project.assignable_users
    users << author if author
    users << assigned_to if assigned_to
    users.uniq.sort
  end

  # Versions that the issue can be assigned to
  def assignable_versions
    return @assignable_versions if @assignable_versions

    versions = project.shared_versions.open.all
    if fixed_version
      if fixed_version_id_changed?
        # nothing to do
      elsif project_id_changed?
        if project.shared_versions.include?(fixed_version)
          versions << fixed_version
        end
      else
        versions << fixed_version
      end
    end
    @assignable_versions = versions.uniq.sort
  end

  # Returns true if this issue is blocked by another issue that is still open
  def blocked?
    !relations_to.detect {|ir| ir.relation_type == 'blocks' && !ir.issue_from.closed?}.nil?
  end

  # Returns an array of statuses that user is able to apply
  def new_statuses_allowed_to(user=User.current, include_default=false)
    if new_record? && @copied_from
      [IssueStatus.default, @copied_from.status].compact.uniq.sort
    else
      initial_status = nil
      if new_record?
        initial_status = IssueStatus.default
      elsif status_id_was
        initial_status = IssueStatus.find_by_id(status_id_was)
      end
      initial_status ||= status
  
      statuses = initial_status.find_new_statuses_allowed_to(
        user.admin ? Role.all : user.roles_for_project(project),
        tracker,
        author == user,
        assigned_to_id_changed? ? assigned_to_id_was == user.id : assigned_to_id == user.id
        )
      statuses << initial_status unless statuses.empty?
      statuses << IssueStatus.default if include_default
      statuses = statuses.compact.uniq.sort
      blocked? ? statuses.reject {|s| s.is_closed?} : statuses
    end
  end

  def assigned_to_was
    if assigned_to_id_changed? && assigned_to_id_was.present?
      @assigned_to_was ||= User.find_by_id(assigned_to_id_was)
    end
  end

  # Returns the mail adresses of users that should be notified
  def recipients
    notified = []
    # Author and assignee are always notified unless they have been
    # locked or don't want to be notified
    notified << author if author
    if assigned_to
      notified += (assigned_to.is_a?(Group) ? assigned_to.users : [assigned_to])
    end
    if assigned_to_was
      notified += (assigned_to_was.is_a?(Group) ? assigned_to_was.users : [assigned_to_was])
    end
    notified = notified.select {|u| u.active? && u.notify_about?(self)}

    notified += project.notified_users
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! {|user| !visible?(user)}
    notified.collect(&:mail)
  end

  # Returns the number of hours spent on this issue
  def spent_hours
    @spent_hours ||= time_entries.sum(:hours) || 0
  end

  # Returns the total number of hours spent on this issue and its descendants
  #
  # Example:
  #   spent_hours => 0.0
  #   spent_hours => 50.2
  def total_spent_hours
    @total_spent_hours ||= self_and_descendants.sum("#{TimeEntry.table_name}.hours",
      :joins => "LEFT JOIN #{TimeEntry.table_name} ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").to_f || 0.0
  end

  def relations
    @relations ||= (relations_from + relations_to).sort
  end

  # Preloads relations for a collection of issues
  def self.load_relations(issues)
    if issues.any?
      relations = IssueRelation.all(:conditions => ["issue_from_id IN (:ids) OR issue_to_id IN (:ids)", {:ids => issues.map(&:id)}])
      issues.each do |issue|
        issue.instance_variable_set "@relations", relations.select {|r| r.issue_from_id == issue.id || r.issue_to_id == issue.id}
      end
    end
  end

  # Preloads visible spent time for a collection of issues
  def self.load_visible_spent_hours(issues, user=User.current)
    if issues.any?
      hours_by_issue_id = TimeEntry.visible(user).sum(:hours, :group => :issue_id)
      issues.each do |issue|
        issue.instance_variable_set "@spent_hours", (hours_by_issue_id[issue.id] || 0)
      end
    end
  end

  # Finds an issue relation given its id.
  def find_relation(relation_id)
    IssueRelation.find(relation_id, :conditions => ["issue_to_id = ? OR issue_from_id = ?", id, id])
  end

  def all_dependent_issues(except=[])
    except << self
    dependencies = []
    relations_from.each do |relation|
      if relation.issue_to && !except.include?(relation.issue_to)
        dependencies << relation.issue_to
        dependencies += relation.issue_to.all_dependent_issues(except)
      end
    end
    dependencies
  end

  # Returns an array of issues that duplicate this one
  def duplicates
    relations_to.select {|r| r.relation_type == IssueRelation::TYPE_DUPLICATES}.collect {|r| r.issue_from}
  end

  # Returns the due date or the target due date if any
  # Used on gantt chart
  def due_before
    due_date || (fixed_version ? fixed_version.effective_date : nil)
  end

  # Returns the time scheduled for this issue.
  #
  # Example:
  #   Start Date: 2/26/09, End Date: 3/04/09
  #   duration => 6
  def duration
    (start_date && due_date) ? due_date - start_date : 0
  end

  def soonest_start
    @soonest_start ||= (
        relations_to.collect{|relation| relation.successor_soonest_start} +
        ancestors.collect(&:soonest_start)
      ).compact.max
  end

  def reschedule_after(date)
    return if date.nil?
    if leaf?
      if start_date.nil? || start_date < date
        self.start_date, self.due_date = date, date + duration
        begin
          save
        rescue ActiveRecord::StaleObjectError
          reload
          self.start_date, self.due_date = date, date + duration
          save
        end
      end
    else
      leaves.each do |leaf|
        leaf.reschedule_after(date)
      end
    end
  end

  def <=>(issue)
    if issue.nil?
      -1
    elsif root_id != issue.root_id
      (root_id || 0) <=> (issue.root_id || 0)
    else
      (lft || 0) <=> (issue.lft || 0)
    end
  end

  def to_s
    "#{tracker} ##{id}: #{subject}"
  end

  # Returns a string of css classes that apply to the issue
  def css_classes
    s = "issue status-#{status_id} priority-#{priority_id}"
    s << ' closed' if closed?
    s << ' overdue' if overdue?
    s << ' child' if child?
    s << ' parent' unless leaf?
    s << ' private' if is_private?
    s << ' created-by-me' if User.current.logged? && author_id == User.current.id
    s << ' assigned-to-me' if User.current.logged? && assigned_to_id == User.current.id
    s
  end

  # Saves an issue and a time_entry from the parameters
  def save_issue_with_child_records(params, existing_time_entry=nil)
    Issue.transaction do
      if params[:time_entry] && (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?) && User.current.allowed_to?(:log_time, project)
        @time_entry = existing_time_entry || TimeEntry.new
        @time_entry.project = project
        @time_entry.issue = self
        @time_entry.user = User.current
        @time_entry.spent_on = User.current.today
        @time_entry.attributes = params[:time_entry]
        self.time_entries << @time_entry
      end

      # TODO: Rename hook
      Redmine::Hook.call_hook(:controller_issues_edit_before_save, { :params => params, :issue => self, :time_entry => @time_entry, :journal => @current_journal})
      if save
        # TODO: Rename hook
        Redmine::Hook.call_hook(:controller_issues_edit_after_save, { :params => params, :issue => self, :time_entry => @time_entry, :journal => @current_journal})
      else
        raise ActiveRecord::Rollback
      end
    end
  end

  # Unassigns issues from +version+ if it's no longer shared with issue's project
  def self.update_versions_from_sharing_change(version)
    # Update issues assigned to the version
    update_versions(["#{Issue.table_name}.fixed_version_id = ?", version.id])
  end

  # Unassigns issues from versions that are no longer shared
  # after +project+ was moved
  def self.update_versions_from_hierarchy_change(project)
    moved_project_ids = project.self_and_descendants.reload.collect(&:id)
    # Update issues of the moved projects and issues assigned to a version of a moved project
    Issue.update_versions(["#{Version.table_name}.project_id IN (?) OR #{Issue.table_name}.project_id IN (?)", moved_project_ids, moved_project_ids])
  end

  def parent_issue_id=(arg)
    parent_issue_id = arg.blank? ? nil : arg.to_i
    if parent_issue_id && @parent_issue = Issue.find_by_id(parent_issue_id)
      @parent_issue.id
    else
      @parent_issue = nil
      nil
    end
  end

  def parent_issue_id
    if instance_variable_defined? :@parent_issue
      @parent_issue.nil? ? nil : @parent_issue.id
    else
      parent_id
    end
  end

  # Extracted from the ReportsController.
  def self.by_tracker(project)
    count_and_group_by(:project => project,
                       :field => 'tracker_id',
                       :joins => Tracker.table_name)
  end

  def self.by_version(project)
    count_and_group_by(:project => project,
                       :field => 'fixed_version_id',
                       :joins => Version.table_name)
  end

  def self.by_priority(project)
    count_and_group_by(:project => project,
                       :field => 'priority_id',
                       :joins => IssuePriority.table_name)
  end

  def self.by_category(project)
    count_and_group_by(:project => project,
                       :field => 'category_id',
                       :joins => IssueCategory.table_name)
  end

  def self.by_assigned_to(project)
    count_and_group_by(:project => project,
                       :field => 'assigned_to_id',
                       :joins => User.table_name)
  end

  def self.by_author(project)
    count_and_group_by(:project => project,
                       :field => 'author_id',
                       :joins => User.table_name)
  end

  def self.by_subproject(project)
    ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                s.is_closed as closed, 
                                                #{Issue.table_name}.project_id as project_id,
                                                count(#{Issue.table_name}.id) as total 
                                              from 
                                                #{Issue.table_name}, #{Project.table_name}, #{IssueStatus.table_name} s
                                              where 
                                                #{Issue.table_name}.status_id=s.id
                                                and #{Issue.table_name}.project_id = #{Project.table_name}.id
                                                and #{visible_condition(User.current, :project => project, :with_subprojects => true)}
                                                and #{Issue.table_name}.project_id <> #{project.id}
                                              group by s.id, s.is_closed, #{Issue.table_name}.project_id") if project.descendants.active.any?
  end
  # End ReportsController extraction

  # Returns an array of projects that user can assign the issue to
  def allowed_target_projects(user=User.current)
    if new_record?
      Project.all(:conditions => Project.allowed_to_condition(user, :add_issues))
    else
      self.class.allowed_target_projects_on_move(user)
    end
  end

  # Returns an array of projects that user can move issues to
  def self.allowed_target_projects_on_move(user=User.current)
    Project.all(:conditions => Project.allowed_to_condition(user, :move_issues))
  end

  private

  def after_project_change
    # Update project_id on related time entries
    TimeEntry.update_all(["project_id = ?", project_id], {:issue_id => id})

    # Delete issue relations
    unless Setting.cross_project_issue_relations?
      relations_from.clear
      relations_to.clear
    end

    # Move subtasks
    children.each do |child|
      # Change project and keep project
      child.send :project=, project, true
      unless child.save
        raise ActiveRecord::Rollback
      end
    end
  end

  # Copies subtasks from the copied issue
  def after_create_from_copy
    return unless copy?

    unless @copied_from.leaf? || @copy_options[:subtasks] == false || @subtasks_copied
      @copied_from.children.each do |child|
        unless child.visible?
          # Do not copy subtasks that are not visible to avoid potential disclosure of private data
          logger.error "Subtask ##{child.id} was not copied during ##{@copied_from.id} copy because it is not visible to the current user" if logger
          next
        end
        copy = Issue.new.copy_from(child, @copy_options)
        copy.author = author
        copy.project = project
        copy.parent_issue_id = id
        # Children subtasks are copied recursively
        unless copy.save
          logger.error "Could not copy subtask ##{child.id} while copying ##{@copied_from.id} to ##{id} due to validation errors: #{copy.errors.full_messages.join(', ')}" if logger
        end
      end
      @subtasks_copied = true
    end
  end

  def update_nested_set_attributes
    if root_id.nil?
      # issue was just created
      self.root_id = (@parent_issue.nil? ? id : @parent_issue.root_id)
      set_default_left_and_right
      Issue.update_all("root_id = #{root_id}, lft = #{lft}, rgt = #{rgt}", ["id = ?", id])
      if @parent_issue
        move_to_child_of(@parent_issue)
      end
      reload
    elsif parent_issue_id != parent_id
      former_parent_id = parent_id
      # moving an existing issue
      if @parent_issue && @parent_issue.root_id == root_id
        # inside the same tree
        move_to_child_of(@parent_issue)
      else
        # to another tree
        unless root?
          move_to_right_of(root)
          reload
        end
        old_root_id = root_id
        self.root_id = (@parent_issue.nil? ? id : @parent_issue.root_id )
        target_maxright = nested_set_scope.maximum(right_column_name) || 0
        offset = target_maxright + 1 - lft
        Issue.update_all("root_id = #{root_id}, lft = lft + #{offset}, rgt = rgt + #{offset}",
                          ["root_id = ? AND lft >= ? AND rgt <= ? ", old_root_id, lft, rgt])
        self[left_column_name] = lft + offset
        self[right_column_name] = rgt + offset
        if @parent_issue
          move_to_child_of(@parent_issue)
        end
      end
      reload
      # delete invalid relations of all descendants
      self_and_descendants.each do |issue|
        issue.relations.each do |relation|
          relation.destroy unless relation.valid?
        end
      end
      # update former parent
      recalculate_attributes_for(former_parent_id) if former_parent_id
    end
    remove_instance_variable(:@parent_issue) if instance_variable_defined?(:@parent_issue)
  end

  def update_parent_attributes
    recalculate_attributes_for(parent_id) if parent_id
  end

  def recalculate_attributes_for(issue_id)
    if issue_id && p = Issue.find_by_id(issue_id)
      # priority = highest priority of children
      if priority_position = p.children.maximum("#{IssuePriority.table_name}.position", :joins => :priority)
        p.priority = IssuePriority.find_by_position(priority_position)
      end

      # start/due dates = lowest/highest dates of children
      p.start_date = p.children.minimum(:start_date)
      p.due_date = p.children.maximum(:due_date)
      if p.start_date && p.due_date && p.due_date < p.start_date
        p.start_date, p.due_date = p.due_date, p.start_date
      end

      # done ratio = weighted average ratio of leaves
      unless Issue.use_status_for_done_ratio? && p.status && p.status.default_done_ratio
        leaves_count = p.leaves.count
        if leaves_count > 0
          average = p.leaves.average(:estimated_hours).to_f
          if average == 0
            average = 1
          end
          done = p.leaves.sum("COALESCE(estimated_hours, #{average}) * (CASE WHEN is_closed = #{connection.quoted_true} THEN 100 ELSE COALESCE(done_ratio, 0) END)", :joins => :status).to_f
          progress = done / (average * leaves_count)
          p.done_ratio = progress.round
        end
      end

      # estimate = sum of leaves estimates
      p.estimated_hours = p.leaves.sum(:estimated_hours).to_f
      p.estimated_hours = nil if p.estimated_hours == 0.0

      # ancestors will be recursively updated
      p.save(:validate => false)
    end
  end

  # Update issues so their versions are not pointing to a
  # fixed_version that is not shared with the issue's project
  def self.update_versions(conditions=nil)
    # Only need to update issues with a fixed_version from
    # a different project and that is not systemwide shared
    Issue.scoped(:conditions => conditions).all(
      :conditions => "#{Issue.table_name}.fixed_version_id IS NOT NULL" +
        " AND #{Issue.table_name}.project_id <> #{Version.table_name}.project_id" +
        " AND #{Version.table_name}.sharing <> 'system'",
      :include => [:project, :fixed_version]
    ).each do |issue|
      next if issue.project.nil? || issue.fixed_version.nil?
      unless issue.project.shared_versions.include?(issue.fixed_version)
        issue.init_journal(User.current)
        issue.fixed_version = nil
        issue.save
      end
    end
  end

  # Callback on attachment deletion
  def attachment_added(obj)
    if @current_journal && !obj.new_record?
      @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :value => obj.filename)
    end
  end

  # Callback on attachment deletion
  def attachment_removed(obj)
    if @current_journal && !obj.new_record?
      @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :old_value => obj.filename)
      @current_journal.save
    end
  end

  # Default assignment based on category
  def default_assign
    if assigned_to.nil? && category && category.assigned_to
      self.assigned_to = category.assigned_to
    end
  end

  # Updates start/due dates of following issues
  def reschedule_following_issues
    if start_date_changed? || due_date_changed?
      relations_from.each do |relation|
        relation.set_issue_to_dates
      end
    end
  end

  # Closes duplicates if the issue is being closed
  def close_duplicates
    if closing?
      duplicates.each do |duplicate|
        # Reload is need in case the duplicate was updated by a previous duplicate
        duplicate.reload
        # Don't re-close it if it's already closed
        next if duplicate.closed?
        # Same user and notes
        if @current_journal
          duplicate.init_journal(@current_journal.user, @current_journal.notes)
        end
        duplicate.update_attribute :status, self.status
      end
    end
  end

  # Make sure updated_on is updated when adding a note
  def force_updated_on_change
    if @current_journal
      self.updated_on = current_time_from_proper_timezone
    end
  end

  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if @current_journal
      # attributes changes
      if @attributes_before_change
        (Issue.column_names - %w(id root_id lft rgt lock_version created_on updated_on)).each {|c|
          before = @attributes_before_change[c]
          after = send(c)
          next if before == after || (before.blank? && after.blank?)
          @current_journal.details << JournalDetail.new(:property => 'attr',
                                                        :prop_key => c,
                                                        :old_value => before,
                                                        :value => after)
        }
      end
      if @custom_values_before_change
        # custom fields changes
        custom_field_values.each {|c|
          before = @custom_values_before_change[c.custom_field_id]
          after = c.value
          next if before == after || (before.blank? && after.blank?)
          
          if before.is_a?(Array) || after.is_a?(Array)
            before = [before] unless before.is_a?(Array)
            after = [after] unless after.is_a?(Array)
            
            # values removed
            (before - after).reject(&:blank?).each do |value|
              @current_journal.details << JournalDetail.new(:property => 'cf',
                                                            :prop_key => c.custom_field_id,
                                                            :old_value => value,
                                                            :value => nil)
            end
            # values added
            (after - before).reject(&:blank?).each do |value|
              @current_journal.details << JournalDetail.new(:property => 'cf',
                                                            :prop_key => c.custom_field_id,
                                                            :old_value => nil,
                                                            :value => value)
            end
          else
            @current_journal.details << JournalDetail.new(:property => 'cf',
                                                          :prop_key => c.custom_field_id,
                                                          :old_value => before,
                                                          :value => after)
          end
        }
      end
      @current_journal.save
      # reset current journal
      init_journal @current_journal.user, @current_journal.notes
    end
  end

  # Query generator for selecting groups of issue counts for a project
  # based on specific criteria
  #
  # Options
  # * project - Project to search in.
  # * field - String. Issue field to key off of in the grouping.
  # * joins - String. The table name to join against.
  def self.count_and_group_by(options)
    project = options.delete(:project)
    select_field = options.delete(:field)
    joins = options.delete(:joins)

    where = "#{Issue.table_name}.#{select_field}=j.id"

    ActiveRecord::Base.connection.select_all("select    s.id as status_id, 
                                                s.is_closed as closed, 
                                                j.id as #{select_field},
                                                count(#{Issue.table_name}.id) as total 
                                              from 
                                                  #{Issue.table_name}, #{Project.table_name}, #{IssueStatus.table_name} s, #{joins} j
                                              where 
                                                #{Issue.table_name}.status_id=s.id 
                                                and #{where}
                                                and #{Issue.table_name}.project_id=#{Project.table_name}.id
                                                and #{visible_condition(User.current, :project => project)}
                                              group by s.id, s.is_closed, j.id")
  end
end
