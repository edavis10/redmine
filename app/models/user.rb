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

require "digest/sha1"

class User < Principal
  include Redmine::SafeAttributes

  # Account statuses
  STATUS_ANONYMOUS  = 0
  STATUS_ACTIVE     = 1
  STATUS_REGISTERED = 2
  STATUS_LOCKED     = 3

  # Different ways of displaying/sorting users
  USER_FORMATS = {
    :firstname_lastname => {:string => '#{firstname} #{lastname}', :order => %w(firstname lastname id)},
    :firstname => {:string => '#{firstname}', :order => %w(firstname id)},
    :lastname_firstname => {:string => '#{lastname} #{firstname}', :order => %w(lastname firstname id)},
    :lastname_coma_firstname => {:string => '#{lastname}, #{firstname}', :order => %w(lastname firstname id)},
    :username => {:string => '#{login}', :order => %w(login id)},
  }

  MAIL_NOTIFICATION_OPTIONS = [
    ['all', :label_user_mail_option_all],
    ['selected', :label_user_mail_option_selected],
    ['only_my_events', :label_user_mail_option_only_my_events],
    ['only_assigned', :label_user_mail_option_only_assigned],
    ['only_owner', :label_user_mail_option_only_owner],
    ['none', :label_user_mail_option_none]
  ]

  has_and_belongs_to_many :groups, :after_add => Proc.new {|user, group| group.user_added(user)},
                                   :after_remove => Proc.new {|user, group| group.user_removed(user)}
  has_many :changesets, :dependent => :nullify
  has_one :preference, :dependent => :destroy, :class_name => 'UserPreference'
  has_one :rss_token, :class_name => 'Token', :conditions => "action='feeds'"
  has_one :api_token, :class_name => 'Token', :conditions => "action='api'"
  belongs_to :auth_source

  scope :logged, :conditions => "#{User.table_name}.status <> #{STATUS_ANONYMOUS}"
  scope :status, lambda {|arg| arg.blank? ? {} : {:conditions => {:status => arg.to_i}} }

  acts_as_customizable

  attr_accessor :password, :password_confirmation
  attr_accessor :last_before_login_on
  # Prevents unauthorized assignments
  attr_protected :login, :admin, :password, :password_confirmation, :hashed_password

  LOGIN_LENGTH_LIMIT = 60
  MAIL_LENGTH_LIMIT = 60

  validates_presence_of :login, :firstname, :lastname, :mail, :if => Proc.new { |user| !user.is_a?(AnonymousUser) }
  validates_uniqueness_of :login, :if => Proc.new { |user| user.login_changed? && user.login.present? }, :case_sensitive => false
  validates_uniqueness_of :mail, :if => Proc.new { |user| !user.mail.blank? }, :case_sensitive => false
  # Login must contain lettres, numbers, underscores only
  validates_format_of :login, :with => /^[a-z0-9_\-@\.]*$/i
  validates_length_of :login, :maximum => LOGIN_LENGTH_LIMIT
  validates_length_of :firstname, :lastname, :maximum => 30
  validates_format_of :mail, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :allow_blank => true
  validates_length_of :mail, :maximum => MAIL_LENGTH_LIMIT, :allow_nil => true
  validates_confirmation_of :password, :allow_nil => true
  validates_inclusion_of :mail_notification, :in => MAIL_NOTIFICATION_OPTIONS.collect(&:first), :allow_blank => true
  validate :validate_password_length

  before_create :set_mail_notification
  before_save   :update_hashed_password
  before_destroy :remove_references_before_destroy

  scope :in_group, lambda {|group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    { :conditions => ["#{User.table_name}.id IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id] }
  }
  scope :not_in_group, lambda {|group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    { :conditions => ["#{User.table_name}.id NOT IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id] }
  }

  def set_mail_notification
    self.mail_notification = Setting.default_notification_option if self.mail_notification.blank?
    true
  end

  def update_hashed_password
    # update hashed_password if password was set
    if self.password && self.auth_source_id.blank?
      salt_password(password)
    end
  end

  def reload(*args)
    @name = nil
    @projects_by_role = nil
    super
  end

  def mail=(arg)
    write_attribute(:mail, arg.to_s.strip)
  end

  def identity_url=(url)
    if url.blank?
      write_attribute(:identity_url, '')
    else
      begin
        write_attribute(:identity_url, OpenIdAuthentication.normalize_identifier(url))
      rescue OpenIdAuthentication::InvalidOpenId
        # Invlaid url, don't save
      end
    end
    self.read_attribute(:identity_url)
  end

  # Returns the user that matches provided login and password, or nil
  def self.try_to_login(login, password)
    login = login.to_s
    password = password.to_s

    # Make sure no one can sign in with an empty password
    return nil if password.empty?
    user = find_by_login(login)
    if user
      # user is already in local database
      return nil if !user.active?
      if user.auth_source
        # user has an external authentication method
        return nil unless user.auth_source.authenticate(login, password)
      else
        # authentication with local password
        return nil unless user.check_password?(password)
      end
    else
      # user is not yet registered, try to authenticate with available sources
      attrs = AuthSource.authenticate(login, password)
      if attrs
        user = new(attrs)
        user.login = login
        user.language = Setting.default_language
        if user.save
          user.reload
          logger.info("User '#{user.login}' created from external auth source: #{user.auth_source.type} - #{user.auth_source.name}") if logger && user.auth_source
        end
      end
    end
    user.update_attribute(:last_login_on, Time.now) if user && !user.new_record?
    user
  rescue => text
    raise text
  end

  # Returns the user who matches the given autologin +key+ or nil
  def self.try_to_autologin(key)
    tokens = Token.find_all_by_action_and_value('autologin', key.to_s)
    # Make sure there's only 1 token that matches the key
    if tokens.size == 1
      token = tokens.first
      if (token.created_on > Setting.autologin.to_i.day.ago) && token.user && token.user.active?
        token.user.update_attribute(:last_login_on, Time.now)
        token.user
      end
    end
  end

  def self.name_formatter(formatter = nil)
    USER_FORMATS[formatter || Setting.user_format] || USER_FORMATS[:firstname_lastname]
  end

  # Returns an array of fields names than can be used to make an order statement for users
  # according to how user names are displayed
  # Examples:
  #
  #   User.fields_for_order_statement              => ['users.login', 'users.id']
  #   User.fields_for_order_statement('authors')   => ['authors.login', 'authors.id']
  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    name_formatter[:order].map {|field| "#{table}.#{field}"}
  end

  # Return user's full name for display
  def name(formatter = nil)
    f = self.class.name_formatter(formatter)
    if formatter
      eval('"' + f[:string] + '"')
    else
      @name ||= eval('"' + f[:string] + '"')
    end
  end

  def active?
    self.status == STATUS_ACTIVE
  end

  def registered?
    self.status == STATUS_REGISTERED
  end

  def locked?
    self.status == STATUS_LOCKED
  end

  def activate
    self.status = STATUS_ACTIVE
  end

  def register
    self.status = STATUS_REGISTERED
  end

  def lock
    self.status = STATUS_LOCKED
  end

  def activate!
    update_attribute(:status, STATUS_ACTIVE)
  end

  def register!
    update_attribute(:status, STATUS_REGISTERED)
  end

  def lock!
    update_attribute(:status, STATUS_LOCKED)
  end

  # Returns true if +clear_password+ is the correct user's password, otherwise false
  def check_password?(clear_password)
    if auth_source_id.present?
      auth_source.authenticate(self.login, clear_password)
    else
      User.hash_password("#{salt}#{User.hash_password clear_password}") == hashed_password
    end
  end

  # Generates a random salt and computes hashed_password for +clear_password+
  # The hashed password is stored in the following form: SHA1(salt + SHA1(password))
  def salt_password(clear_password)
    self.salt = User.generate_salt
    self.hashed_password = User.hash_password("#{salt}#{User.hash_password clear_password}")
  end

  # Does the backend storage allow this user to change their password?
  def change_password_allowed?
    return true if auth_source.nil?
    return auth_source.allow_password_changes?
  end

  # Generate and set a random password.  Useful for automated user creation
  # Based on Token#generate_token_value
  #
  def random_password
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    password = ''
    40.times { |i| password << chars[rand(chars.size-1)] }
    self.password = password
    self.password_confirmation = password
    self
  end

  def pref
    self.preference ||= UserPreference.new(:user => self)
  end

  def time_zone
    @time_zone ||= (self.pref.time_zone.blank? ? nil : ActiveSupport::TimeZone[self.pref.time_zone])
  end

  def wants_comments_in_reverse_order?
    self.pref[:comments_sorting] == 'desc'
  end

  # Return user's RSS key (a 40 chars long string), used to access feeds
  def rss_key
    if rss_token.nil?
      create_rss_token(:action => 'feeds')
    end
    rss_token.value
  end

  # Return user's API key (a 40 chars long string), used to access the API
  def api_key
    if api_token.nil?
      create_api_token(:action => 'api')
    end
    api_token.value
  end

  # Return an array of project ids for which the user has explicitly turned mail notifications on
  def notified_projects_ids
    @notified_projects_ids ||= memberships.select {|m| m.mail_notification?}.collect(&:project_id)
  end

  def notified_project_ids=(ids)
    Member.update_all("mail_notification = #{connection.quoted_false}", ['user_id = ?', id])
    Member.update_all("mail_notification = #{connection.quoted_true}", ['user_id = ? AND project_id IN (?)', id, ids]) if ids && !ids.empty?
    @notified_projects_ids = nil
    notified_projects_ids
  end

  def valid_notification_options
    self.class.valid_notification_options(self)
  end

  # Only users that belong to more than 1 project can select projects for which they are notified
  def self.valid_notification_options(user=nil)
    # Note that @user.membership.size would fail since AR ignores
    # :include association option when doing a count
    if user.nil? || user.memberships.length < 1
      MAIL_NOTIFICATION_OPTIONS.reject {|option| option.first == 'selected'}
    else
      MAIL_NOTIFICATION_OPTIONS
    end
  end

  # Find a user account by matching the exact login and then a case-insensitive
  # version.  Exact matches will be given priority.
  def self.find_by_login(login)
    # First look for an exact match
    user = all(:conditions => {:login => login}).detect {|u| u.login == login}
    unless user
      # Fail over to case-insensitive if none was found
      user = first(:conditions => ["LOWER(login) = ?", login.to_s.downcase])
    end
    user
  end

  def self.find_by_rss_key(key)
    token = Token.find_by_action_and_value('feeds', key.to_s)
    token && token.user.active? ? token.user : nil
  end

  def self.find_by_api_key(key)
    token = Token.find_by_action_and_value('api', key.to_s)
    token && token.user.active? ? token.user : nil
  end

  # Makes find_by_mail case-insensitive
  def self.find_by_mail(mail)
    find(:first, :conditions => ["LOWER(mail) = ?", mail.to_s.downcase])
  end

  # Returns true if the default admin account can no longer be used
  def self.default_admin_account_changed?
    !User.active.find_by_login("admin").try(:check_password?, "admin")
  end

  def to_s
    name
  end

  # Returns the current day according to user's time zone
  def today
    if time_zone.nil?
      Date.today
    else
      Time.now.in_time_zone(time_zone).to_date
    end
  end

  # Returns the day of +time+ according to user's time zone
  def time_to_date(time)
    if time_zone.nil?
      time.to_date
    else
      time.in_time_zone(time_zone).to_date
    end
  end

  def logged?
    true
  end

  def anonymous?
    !logged?
  end

  # Return user's roles for project
  def roles_for_project(project)
    roles = []
    # No role on archived projects
    return roles if project.nil? || project.archived?
    if logged?
      # Find project membership
      membership = memberships.detect {|m| m.project_id == project.id}
      if membership
        roles = membership.roles
      else
        @role_non_member ||= Role.non_member
        roles << @role_non_member
      end
    else
      @role_anonymous ||= Role.anonymous
      roles << @role_anonymous
    end
    roles
  end

  # Return true if the user is a member of project
  def member_of?(project)
    !roles_for_project(project).detect {|role| role.member?}.nil?
  end

  # Returns a hash of user's projects grouped by roles
  def projects_by_role
    return @projects_by_role if @projects_by_role

    @projects_by_role = Hash.new([])
    memberships.each do |membership|
      if membership.project
        membership.roles.each do |role|
          @projects_by_role[role] = [] unless @projects_by_role.key?(role)
          @projects_by_role[role] << membership.project
        end
      end
    end
    @projects_by_role.each do |role, projects|
      projects.uniq!
    end

    @projects_by_role
  end

  # Returns true if user is arg or belongs to arg
  def is_or_belongs_to?(arg)
    if arg.is_a?(User)
      self == arg
    elsif arg.is_a?(Group)
      arg.users.include?(self)
    else
      false
    end
  end

  # Return true if the user is allowed to do the specified action on a specific context
  # Action can be:
  # * a parameter-like Hash (eg. :controller => 'projects', :action => 'edit')
  # * a permission Symbol (eg. :edit_project)
  # Context can be:
  # * a project : returns true if user is allowed to do the specified action on this project
  # * an array of projects : returns true if user is allowed on every project
  # * nil with options[:global] set : check if user has at least one role allowed for this action,
  #   or falls back to Non Member / Anonymous permissions depending if the user is logged
  def allowed_to?(action, context, options={}, &block)
    if context && context.is_a?(Project)
      return false unless context.allows_to?(action)
      # Admin users are authorized for anything else
      return true if admin?

      roles = roles_for_project(context)
      return false unless roles
      roles.detect {|role|
        (context.is_public? || role.member?) &&
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    elsif context && context.is_a?(Array)
      # Authorize if user is authorized on every element of the array
      context.map do |project|
        allowed_to?(action, project, options, &block)
      end.inject do |memo,allowed|
        memo && allowed
      end
    elsif options[:global]
      # Admin users are always authorized
      return true if admin?

      # authorize if user has at least one role that has this permission
      roles = memberships.collect {|m| m.roles}.flatten.uniq
      roles << (self.logged? ? Role.non_member : Role.anonymous)
      roles.detect {|role|
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    else
      false
    end
  end

  # Is the user allowed to do the specified action on any project?
  # See allowed_to? for the actions and valid options.
  def allowed_to_globally?(action, options, &block)
    allowed_to?(action, nil, options.reverse_merge(:global => true), &block)
  end

  # Returns true if the user is allowed to delete his own account
  def own_account_deletable?
    Setting.unsubscribe? &&
      (!admin? || User.active.first(:conditions => ["admin = ? AND id <> ?", true, id]).present?)
  end

  safe_attributes 'login',
    'firstname',
    'lastname',
    'mail',
    'mail_notification',
    'language',
    'custom_field_values',
    'custom_fields',
    'identity_url'

  safe_attributes 'status',
    'auth_source_id',
    :if => lambda {|user, current_user| current_user.admin?}

  safe_attributes 'group_ids',
    :if => lambda {|user, current_user| current_user.admin? && !user.new_record?}

  # Utility method to help check if a user should be notified about an
  # event.
  #
  # TODO: only supports Issue events currently
  def notify_about?(object)
    case mail_notification
    when 'all'
      true
    when 'selected'
      # user receives notifications for created/assigned issues on unselected projects
      if object.is_a?(Issue) && (object.author == self || is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was))
        true
      else
        false
      end
    when 'none'
      false
    when 'only_my_events'
      if object.is_a?(Issue) && (object.author == self || is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was))
        true
      else
        false
      end
    when 'only_assigned'
      if object.is_a?(Issue) && (is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was))
        true
      else
        false
      end
    when 'only_owner'
      if object.is_a?(Issue) && object.author == self
        true
      else
        false
      end
    else
      false
    end
  end

  def self.current=(user)
    @current_user = user
  end

  def self.current
    @current_user ||= User.anonymous
  end

  # Returns the anonymous user.  If the anonymous user does not exist, it is created.  There can be only
  # one anonymous user per database.
  def self.anonymous
    anonymous_user = AnonymousUser.find(:first)
    if anonymous_user.nil?
      anonymous_user = AnonymousUser.create(:lastname => 'Anonymous', :firstname => '', :mail => '', :login => '', :status => 0)
      raise 'Unable to create the anonymous user.' if anonymous_user.new_record?
    end
    anonymous_user
  end

  # Salts all existing unsalted passwords
  # It changes password storage scheme from SHA1(password) to SHA1(salt + SHA1(password))
  # This method is used in the SaltPasswords migration and is to be kept as is
  def self.salt_unsalted_passwords!
    transaction do
      User.find_each(:conditions => "salt IS NULL OR salt = ''") do |user|
        next if user.hashed_password.blank?
        salt = User.generate_salt
        hashed_password = User.hash_password("#{salt}#{user.hashed_password}")
        User.update_all("salt = '#{salt}', hashed_password = '#{hashed_password}'", ["id = ?", user.id] )
      end
    end
  end

  protected

  def validate_password_length
    # Password length validation based on setting
    if !password.nil? && password.size < Setting.password_min_length.to_i
      errors.add(:password, :too_short, :count => Setting.password_min_length.to_i)
    end
  end

  private

  # Removes references that are not handled by associations
  # Things that are not deleted are reassociated with the anonymous user
  def remove_references_before_destroy
    return if self.id.nil?

    substitute = User.anonymous
    Attachment.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
    Comment.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
    Issue.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
    Issue.update_all 'assigned_to_id = NULL', ['assigned_to_id = ?', id]
    Journal.update_all ['user_id = ?', substitute.id], ['user_id = ?', id]
    JournalDetail.update_all ['old_value = ?', substitute.id.to_s], ["property = 'attr' AND prop_key = 'assigned_to_id' AND old_value = ?", id.to_s]
    JournalDetail.update_all ['value = ?', substitute.id.to_s], ["property = 'attr' AND prop_key = 'assigned_to_id' AND value = ?", id.to_s]
    Message.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
    News.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
    # Remove private queries and keep public ones
    ::Query.delete_all ['user_id = ? AND is_public = ?', id, false]
    ::Query.update_all ['user_id = ?', substitute.id], ['user_id = ?', id]
    TimeEntry.update_all ['user_id = ?', substitute.id], ['user_id = ?', id]
    Token.delete_all ['user_id = ?', id]
    Watcher.delete_all ['user_id = ?', id]
    WikiContent.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
    WikiContent::Version.update_all ['author_id = ?', substitute.id], ['author_id = ?', id]
  end

  # Return password digest
  def self.hash_password(clear_password)
    Digest::SHA1.hexdigest(clear_password || "")
  end

  # Returns a 128bits random salt as a hex string (32 chars long)
  def self.generate_salt
    Redmine::Utils.random_hex(16)
  end

end

class AnonymousUser < User
  validate :validate_anonymous_uniqueness, :on => :create

  def validate_anonymous_uniqueness
    # There should be only one AnonymousUser in the database
    errors.add :base, 'An anonymous user already exists.' if AnonymousUser.find(:first)
  end

  def available_custom_fields
    []
  end

  # Overrides a few properties
  def logged?; false end
  def admin; false end
  def name(*args); I18n.t(:label_user_anonymous) end
  def mail; nil end
  def time_zone; nil end
  def rss_key; nil end

  def pref
    UserPreference.new(:user => self)
  end

  # Anonymous user can not be destroyed
  def destroy
    false
  end
end
