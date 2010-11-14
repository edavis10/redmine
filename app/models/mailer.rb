# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

require 'ar_condition'

class Mailer < ActionMailer::Base
  layout 'mailer'
  helper :application
  helper :issues
  helper :custom_fields

  include ActionController::UrlWriter
  include Redmine::I18n

  def self.default_url_options
    h = Setting.host_name
    h = h.to_s.gsub(%r{\/.*$}, '') unless Redmine::Utils.relative_url_root.blank?
    { :host => h, :protocol => Setting.protocol }
  end
  
  # Builds a tmail object used to email recipients of the added issue.
  #
  # Example:
  #   issue_add(issue) => tmail object
  #   Mailer.deliver_issue_add(issue) => sends an email to issue recipients
  def issue_add(issue)
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    message_id issue
    recipients issue.recipients
    cc(issue.watcher_recipients - @recipients)
    subject "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] (#{issue.status.name}) #{issue.subject}"
    body :issue => issue,
         :issue_url => url_for(:controller => 'issues', :action => 'show', :id => issue)
    render_multipart('issue_add', body)
  end

  # Builds a tmail object used to email recipients of the edited issue.
  #
  # Example:
  #   issue_edit(journal) => tmail object
  #   Mailer.deliver_issue_edit(journal) => sends an email to issue recipients
  def issue_edit(journal)
    issue = journal.journalized.reload
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    message_id journal
    references issue
    @author = journal.user
    recipients issue.recipients
    # Watchers in cc
    cc(issue.watcher_recipients - @recipients)
    s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
    s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
    s << issue.subject
    subject s
    body :issue => issue,
         :journal => journal,
         :issue_url => url_for(:controller => 'issues', :action => 'show', :id => issue)

    render_multipart('issue_edit', body)
  end

  def reminder(user, issues, days)
    set_language_if_valid user.language
    recipients user.mail
    subject l(:mail_subject_reminder, :count => issues.size, :days => days)
    body :issues => issues,
         :days => days,
         :issues_url => url_for(:controller => 'issues', :action => 'index', :set_filter => 1, :assigned_to_id => user.id, :sort_key => 'due_date', :sort_order => 'asc')
    render_multipart('reminder', body)
  end

  # Builds a tmail object used to email users belonging to the added document's project.
  #
  # Example:
  #   document_added(document) => tmail object
  #   Mailer.deliver_document_added(document) => sends an email to the document's project recipients
  def document_added(document)
    redmine_headers 'Project' => document.project.identifier
    recipients document.recipients
    subject "[#{document.project.name}] #{l(:label_document_new)}: #{document.title}"
    body :document => document,
         :document_url => url_for(:controller => 'documents', :action => 'show', :id => document)
    render_multipart('document_added', body)
  end

  # Builds a tmail object used to email recipients of a project when an attachements are added.
  #
  # Example:
  #   attachments_added(attachments) => tmail object
  #   Mailer.deliver_attachments_added(attachments) => sends an email to the project's recipients
  def attachments_added(attachments)
    container = attachments.first.container
    added_to = ''
    added_to_url = ''
    case container.class.name
    when 'Project'
      added_to_url = url_for(:controller => 'projects', :action => 'list_files', :id => container)
      added_to = "#{l(:label_project)}: #{container}"
      recipients container.project.notified_users.select {|user| user.allowed_to?(:view_files, container.project)}.collect  {|u| u.mail}
    when 'Version'
      added_to_url = url_for(:controller => 'projects', :action => 'list_files', :id => container.project_id)
      added_to = "#{l(:label_version)}: #{container.name}"
      recipients container.project.notified_users.select {|user| user.allowed_to?(:view_files, container.project)}.collect  {|u| u.mail}
    when 'Document'
      added_to_url = url_for(:controller => 'documents', :action => 'show', :id => container.id)
      added_to = "#{l(:label_document)}: #{container.title}"
      recipients container.recipients
    end
    redmine_headers 'Project' => container.project.identifier
    subject "[#{container.project.name}] #{l(:label_attachment_new)}"
    body :attachments => attachments,
         :added_to => added_to,
         :added_to_url => added_to_url
    render_multipart('attachments_added', body)
  end
  
  # Builds a tmail object used to email recipients of a news' project when a news item is added.
  #
  # Example:
  #   news_added(news) => tmail object
  #   Mailer.deliver_news_added(news) => sends an email to the news' project recipients
  def news_added(news)
    redmine_headers 'Project' => news.project.identifier
    message_id news
    recipients news.recipients
    subject "[#{news.project.name}] #{l(:label_news)}: #{news.title}"
    body :news => news,
         :news_url => url_for(:controller => 'news', :action => 'show', :id => news)
    render_multipart('news_added', body)
  end

  # Builds a tmail object used to email the recipients of the specified message that was posted. 
  #
  # Example:
  #   message_posted(message) => tmail object
  #   Mailer.deliver_message_posted(message) => sends an email to the recipients
  def message_posted(message)
    redmine_headers 'Project' => message.project.identifier,
                    'Topic-Id' => (message.parent_id || message.id)
    message_id message
    references message.parent unless message.parent.nil?
    recipients(message.recipients)
    cc((message.root.watcher_recipients + message.board.watcher_recipients).uniq - @recipients)
    subject "[#{message.board.project.name} - #{message.board.name} - msg#{message.root.id}] #{message.subject}"
    body :message => message,
         :message_url => url_for(message.event_url)
    render_multipart('message_posted', body)
  end
  
  # Builds a tmail object used to email the recipients of a project of the specified wiki content was added. 
  #
  # Example:
  #   wiki_content_added(wiki_content) => tmail object
  #   Mailer.deliver_wiki_content_added(wiki_content) => sends an email to the project's recipients
  def wiki_content_added(wiki_content)
    redmine_headers 'Project' => wiki_content.project.identifier,
                    'Wiki-Page-Id' => wiki_content.page.id
    message_id wiki_content
    recipients wiki_content.recipients
    cc(wiki_content.page.wiki.watcher_recipients - recipients)
    subject "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_added, :id => wiki_content.page.pretty_title)}"
    body :wiki_content => wiki_content,
         :wiki_content_url => url_for(:controller => 'wiki', :action => 'show', :project_id => wiki_content.project, :id => wiki_content.page.title)
    render_multipart('wiki_content_added', body)
  end
  
  # Builds a tmail object used to email the recipients of a project of the specified wiki content was updated. 
  #
  # Example:
  #   wiki_content_updated(wiki_content) => tmail object
  #   Mailer.deliver_wiki_content_updated(wiki_content) => sends an email to the project's recipients
  def wiki_content_updated(wiki_content)
    redmine_headers 'Project' => wiki_content.project.identifier,
                    'Wiki-Page-Id' => wiki_content.page.id
    message_id wiki_content
    recipients wiki_content.recipients
    cc(wiki_content.page.wiki.watcher_recipients + wiki_content.page.watcher_recipients - recipients)
    subject "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_updated, :id => wiki_content.page.pretty_title)}"
    body :wiki_content => wiki_content,
         :wiki_content_url => url_for(:controller => 'wiki', :action => 'show', :project_id => wiki_content.project, :id => wiki_content.page.title),
         :wiki_diff_url => url_for(:controller => 'wiki', :action => 'diff', :project_id => wiki_content.project, :id => wiki_content.page.title, :version => wiki_content.version)
    render_multipart('wiki_content_updated', body)
  end

  # Builds a tmail object used to email the specified user their account information.
  #
  # Example:
  #   account_information(user, password) => tmail object
  #   Mailer.deliver_account_information(user, password) => sends account information to the user
  def account_information(user, password)
    set_language_if_valid user.language
    recipients user.mail
    subject l(:mail_subject_register, Setting.app_title)
    body :user => user,
         :password => password,
         :login_url => url_for(:controller => 'account', :action => 'login')
    render_multipart('account_information', body)
  end

  # Builds a tmail object used to email all active administrators of an account activation request.
  #
  # Example:
  #   account_activation_request(user) => tmail object
  #   Mailer.deliver_account_activation_request(user)=> sends an email to all active administrators
  def account_activation_request(user)
    # Send the email to all active administrators
    recipients User.active.find(:all, :conditions => {:admin => true}).collect { |u| u.mail }.compact
    subject l(:mail_subject_account_activation_request, Setting.app_title)
    body :user => user,
         :url => url_for(:controller => 'users', :action => 'index', :status => User::STATUS_REGISTERED, :sort_key => 'created_on', :sort_order => 'desc')
    render_multipart('account_activation_request', body)
  end

  # Builds a tmail object used to email the specified user that their account was activated by an administrator.
  #
  # Example:
  #   account_activated(user) => tmail object
  #   Mailer.deliver_account_activated(user) => sends an email to the registered user
  def account_activated(user)
    set_language_if_valid user.language
    recipients user.mail
    subject l(:mail_subject_register, Setting.app_title)
    body :user => user,
         :login_url => url_for(:controller => 'account', :action => 'login')
    render_multipart('account_activated', body)
  end

  def lost_password(token)
    set_language_if_valid(token.user.language)
    recipients token.user.mail
    subject l(:mail_subject_lost_password, Setting.app_title)
    body :token => token,
         :url => url_for(:controller => 'account', :action => 'lost_password', :token => token.value)
    render_multipart('lost_password', body)
  end

  def register(token)
    set_language_if_valid(token.user.language)
    recipients token.user.mail
    subject l(:mail_subject_register, Setting.app_title)
    body :token => token,
         :url => url_for(:controller => 'account', :action => 'activate', :token => token.value)
    render_multipart('register', body)
  end

  def test(user)
    set_language_if_valid(user.language)
    recipients user.mail
    subject 'Redmine test'
    body :url => url_for(:controller => 'welcome')
    render_multipart('test', body)
  end

  # Overrides default deliver! method to prevent from sending an email
  # with no recipient, cc or bcc
  def deliver!(mail = @mail)
    set_language_if_valid @initial_language
    return false if (recipients.nil? || recipients.empty?) &&
                    (cc.nil? || cc.empty?) &&
                    (bcc.nil? || bcc.empty?)
                    
    # Set Message-Id and References
    if @message_id_object
      mail.message_id = self.class.message_id_for(@message_id_object)
    end
    if @references_objects
      mail.references = @references_objects.collect {|o| self.class.message_id_for(o)}
    end
    
    # Log errors when raise_delivery_errors is set to false, Rails does not
    raise_errors = self.class.raise_delivery_errors
    self.class.raise_delivery_errors = true
    begin
      return super(mail)
    rescue Exception => e
      if raise_errors
        raise e
      elsif mylogger
        mylogger.error "The following error occured while sending email notification: \"#{e.message}\". Check your configuration in config/email.yml."
      end
    ensure
      self.class.raise_delivery_errors = raise_errors
    end
  end

  # Sends reminders to issue assignees
  # Available options:
  # * :days     => how many days in the future to remind about (defaults to 7)
  # * :tracker  => id of tracker for filtering issues (defaults to all trackers)
  # * :project  => id or identifier of project to process (defaults to all projects)
  # * :users    => array of user ids who should be reminded
  def self.reminders(options={})
    days = options[:days] || 7
    project = options[:project] ? Project.find(options[:project]) : nil
    tracker = options[:tracker] ? Tracker.find(options[:tracker]) : nil
    user_ids = options[:users]

    s = ARCondition.new ["#{IssueStatus.table_name}.is_closed = ? AND #{Issue.table_name}.due_date <= ?", false, days.day.from_now.to_date]
    s << "#{Issue.table_name}.assigned_to_id IS NOT NULL"
    s << ["#{Issue.table_name}.assigned_to_id IN (?)", user_ids] if user_ids.present?
    s << "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}"
    s << "#{Issue.table_name}.project_id = #{project.id}" if project
    s << "#{Issue.table_name}.tracker_id = #{tracker.id}" if tracker

    issues_by_assignee = Issue.find(:all, :include => [:status, :assigned_to, :project, :tracker],
                                          :conditions => s.conditions
                                    ).group_by(&:assigned_to)
    issues_by_assignee.each do |assignee, issues|
      deliver_reminder(assignee, issues, days) unless assignee.nil?
    end
  end
  
  # Activates/desactivates email deliveries during +block+
  def self.with_deliveries(enabled = true, &block)
    was_enabled = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = !!enabled
    yield
  ensure
    ActionMailer::Base.perform_deliveries = was_enabled
  end

  private
  def initialize_defaults(method_name)
    super
    @initial_language = current_language
    set_language_if_valid Setting.default_language
    from Setting.mail_from
    
    # Common headers
    headers 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => Setting.app_title,
            'Precedence' => 'bulk',
            'Auto-Submitted' => 'auto-generated'
  end

  # Appends a Redmine header field (name is prepended with 'X-Redmine-')
  def redmine_headers(h)
    h.each { |k,v| headers["X-Redmine-#{k}"] = v }
  end

  # Overrides the create_mail method
  def create_mail
    # Removes the current user from the recipients and cc
    # if he doesn't want to receive notifications about what he does
    @author ||= User.current
    if @author.pref[:no_self_notified]
      recipients.delete(@author.mail) if recipients
      cc.delete(@author.mail) if cc
    end
    
    notified_users = [recipients, cc].flatten.compact.uniq
    # Rails would log recipients only, not cc and bcc
    mylogger.info "Sending email notification to: #{notified_users.join(', ')}" if mylogger
    
    # Blind carbon copy recipients
    if Setting.bcc_recipients?
      bcc(notified_users)
      recipients []
      cc []
    end
    super
  end

  # Rails 2.3 has problems rendering implicit multipart messages with
  # layouts so this method will wrap an multipart messages with
  # explicit parts.
  #
  # https://rails.lighthouseapp.com/projects/8994/tickets/2338-actionmailer-mailer-views-and-content-type
  # https://rails.lighthouseapp.com/projects/8994/tickets/1799-actionmailer-doesnt-set-template_format-when-rendering-layouts
  
  def render_multipart(method_name, body)
    if Setting.plain_text_mail?
      content_type "text/plain"
      body render(:file => "#{method_name}.text.plain.rhtml", :body => body, :layout => 'mailer.text.plain.erb')
    else
      content_type "multipart/alternative"
      part :content_type => "text/plain", :body => render(:file => "#{method_name}.text.plain.rhtml", :body => body, :layout => 'mailer.text.plain.erb')
      part :content_type => "text/html", :body => render_message("#{method_name}.text.html.rhtml", body)
    end
  end

  # Makes partial rendering work with Rails 1.2 (retro-compatibility)
  def self.controller_path
    ''
  end unless respond_to?('controller_path')
  
  # Returns a predictable Message-Id for the given object
  def self.message_id_for(object)
    # id + timestamp should reduce the odds of a collision
    # as far as we don't send multiple emails for the same object
    timestamp = object.send(object.respond_to?(:created_on) ? :created_on : :updated_on) 
    hash = "redmine.#{object.class.name.demodulize.underscore}-#{object.id}.#{timestamp.strftime("%Y%m%d%H%M%S")}"
    host = Setting.mail_from.to_s.gsub(%r{^.*@}, '')
    host = "#{::Socket.gethostname}.redmine" if host.empty?
    "<#{hash}@#{host}>"
  end
  
  private
  
  def message_id(object)
    @message_id_object = object
  end
  
  def references(object)
    @references_objects ||= []
    @references_objects << object
  end
    
  def mylogger
    RAILS_DEFAULT_LOGGER
  end
end

# Patch TMail so that message_id is not overwritten
module TMail
  class Mail
    def add_message_id( fqdn = nil )
      self.message_id ||= ::TMail::new_message_id(fqdn)
    end
  end
end
