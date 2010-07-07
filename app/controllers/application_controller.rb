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

require 'uri'
require 'cgi'

class ApplicationController < ActionController::Base
  include Redmine::I18n

  layout 'base'
  exempt_from_layout 'builder'
  
  # Remove broken cookie after upgrade from 0.8.x (#4292)
  # See https://rails.lighthouseapp.com/projects/8994/tickets/3360
  # TODO: remove it when Rails is fixed
  before_filter :delete_broken_cookies
  def delete_broken_cookies
    if cookies['_redmine_session'] && cookies['_redmine_session'] !~ /--/
      cookies.delete '_redmine_session'    
      redirect_to home_path
      return false
    end
  end
  
  before_filter :user_setup, :check_if_login_required, :set_localization
  filter_parameter_logging :password
  protect_from_forgery
  
  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalid_authenticity_token
  
  include Redmine::Search::Controller
  include Redmine::MenuManager::MenuController
  helper Redmine::MenuManager::MenuHelper
  
  Redmine::Scm::Base.all.each do |scm|
    require_dependency "repository/#{scm.underscore}"
  end

  def user_setup
    # Check the settings cache for each request
    Setting.check_cache
    # Find the current user
    User.current = find_current_user
  end
  
  # Returns the current user or nil if no user is logged in
  # and starts a session if needed
  def find_current_user
    if session[:user_id]
      # existing session
      (User.active.find(session[:user_id]) rescue nil)
    elsif cookies[:autologin] && Setting.autologin?
      # auto-login feature starts a new session
      user = User.try_to_autologin(cookies[:autologin])
      session[:user_id] = user.id if user
      user
    elsif params[:format] == 'atom' && params[:key] && accept_key_auth_actions.include?(params[:action])
      # RSS key authentication does not start a session
      User.find_by_rss_key(params[:key])
    elsif Setting.rest_api_enabled? && ['xml', 'json'].include?(params[:format])
      if params[:key].present? && accept_key_auth_actions.include?(params[:action])
        # Use API key
        User.find_by_api_key(params[:key])
      else
        # HTTP Basic, either username/password or API key/random
        authenticate_with_http_basic do |username, password|
          User.try_to_login(username, password) || User.find_by_api_key(username)
        end
      end
    end
  end

  # Sets the logged in user
  def logged_user=(user)
    reset_session
    if user && user.is_a?(User)
      User.current = user
      session[:user_id] = user.id
    else
      User.current = User.anonymous
    end
  end
  
  # check if login is globally required to access the application
  def check_if_login_required
    # no check needed if user is already logged in
    return true if User.current.logged?
    require_login if Setting.login_required?
  end 
  
  def set_localization
    lang = nil
    if User.current.logged?
      lang = find_language(User.current.language)
    end
    if lang.nil? && request.env['HTTP_ACCEPT_LANGUAGE']
      accept_lang = parse_qvalues(request.env['HTTP_ACCEPT_LANGUAGE']).first
      if !accept_lang.blank?
        accept_lang = accept_lang.downcase
        lang = find_language(accept_lang) || find_language(accept_lang.split('-').first)
      end
    end
    lang ||= Setting.default_language
    set_language_if_valid(lang)
  end
  
  def require_login
    if !User.current.logged?
      # Extract only the basic url parameters on non-GET requests
      if request.get?
        url = url_for(params)
      else
        url = url_for(:controller => params[:controller], :action => params[:action], :id => params[:id], :project_id => params[:project_id])
      end
      respond_to do |format|
        format.html { redirect_to :controller => "account", :action => "login", :back_url => url }
        format.atom { redirect_to :controller => "account", :action => "login", :back_url => url }
        format.xml  { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
        format.js   { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
        format.json { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"' }
      end
      return false
    end
    true
  end

  def require_admin
    return unless require_login
    if !User.current.admin?
      render_403
      return false
    end
    true
  end
  
  def deny_access
    User.current.logged? ? render_403 : require_login
  end

  # Authorize the user for the requested action
  def authorize(ctrl = params[:controller], action = params[:action], global = false)
    allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project, :global => global)
    allowed ? true : deny_access
  end

  # Authorize the user for the requested action outside a project
  def authorize_global(ctrl = params[:controller], action = params[:action], global = true)
    authorize(ctrl, action, global)
  end

  # Find project of id params[:id]
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Find a project based on params[:project_id]
  # TODO: some subclasses override this, see about merging their logic
  def find_optional_project
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
    allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
    allowed ? true : deny_access
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Finds and sets @project based on @object.project
  def find_project_from_association
    render_404 unless @object.present?
    
    @project = @object.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_model_object
    model = self.class.read_inheritable_attribute('model_object')
    if model
      @object = model.find(params[:id])
      self.instance_variable_set('@' + controller_name.singularize, @object) if @object
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def self.model_object(model)
    write_inheritable_attribute('model_object', model)
  end
    
  # make sure that the user is a member of the project (or admin) if project is private
  # used as a before_filter for actions that do not require any particular permission on the project
  def check_project_privacy
    if @project && @project.active?
      if @project.is_public? || User.current.member_of?(@project) || User.current.admin?
        true
      else
        User.current.logged? ? render_403 : require_login
      end
    else
      @project = nil
      render_404
      false
    end
  end

  def redirect_back_or_default(default)
    back_url = CGI.unescape(params[:back_url].to_s)
    if !back_url.blank?
      begin
        uri = URI.parse(back_url)
        # do not redirect user to another host or to the login or register page
        if (uri.relative? || (uri.host == request.host)) && !uri.path.match(%r{/(login|account/register)})
          redirect_to(back_url)
          return
        end
      rescue URI::InvalidURIError
        # redirect to default
      end
    end
    redirect_to default
  end
  
  def render_403
    @project = nil
    respond_to do |format|
      format.html { render :template => "common/403", :layout => (request.xhr? ? false : 'base'), :status => 403 }
      format.atom { head 403 }
      format.xml { head 403 }
      format.js { head 403 }
      format.json { head 403 }
    end
    return false
  end
    
  def render_404
    respond_to do |format|
      format.html { render :template => "common/404", :layout => !request.xhr?, :status => 404 }
      format.atom { head 404 }
      format.xml { head 404 }
      format.js { head 404 }
      format.json { head 404 }
    end
    return false
  end
  
  def render_error(msg)
    respond_to do |format|
      format.html { 
        flash.now[:error] = msg
        render :text => '', :layout => !request.xhr?, :status => 500
      }
      format.atom { head 500 }
      format.xml { head 500 }
      format.js { head 500 }
      format.json { head 500 }
    end
  end
  
  def invalid_authenticity_token
    if api_request?
      logger.error "Form authenticity token is missing or is invalid. API calls must include a proper Content-type header (text/xml or text/json)."
    end
    render_error "Invalid form authenticity token."
  end
  
  def render_feed(items, options={})    
    @items = items || []
    @items.sort! {|x,y| y.event_datetime <=> x.event_datetime }
    @items = @items.slice(0, Setting.feeds_limit.to_i)
    @title = options[:title] || Setting.app_title
    render :template => "common/feed.atom.rxml", :layout => false, :content_type => 'application/atom+xml'
  end
  
  def self.accept_key_auth(*actions)
    actions = actions.flatten.map(&:to_s)
    write_inheritable_attribute('accept_key_auth_actions', actions)
  end
  
  def accept_key_auth_actions
    self.class.read_inheritable_attribute('accept_key_auth_actions') || []
  end
  
  # Returns the number of objects that should be displayed
  # on the paginated list
  def per_page_option
    per_page = nil
    if params[:per_page] && Setting.per_page_options_array.include?(params[:per_page].to_s.to_i)
      per_page = params[:per_page].to_s.to_i
      session[:per_page] = per_page
    elsif session[:per_page]
      per_page = session[:per_page]
    else
      per_page = Setting.per_page_options_array.first || 25
    end
    per_page
  end

  # qvalues http header parser
  # code taken from webrick
  def parse_qvalues(value)
    tmp = []
    if value
      parts = value.split(/,\s*/)
      parts.each {|part|
        if m = %r{^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$}.match(part)
          val = m[1]
          q = (m[2] or 1).to_f
          tmp.push([val, q])
        end
      }
      tmp = tmp.sort_by{|val, q| -q}
      tmp.collect!{|val, q| val}
    end
    return tmp
  rescue
    nil
  end
  
  # Returns a string that can be used as filename value in Content-Disposition header
  def filename_for_content_disposition(name)
    request.env['HTTP_USER_AGENT'] =~ %r{MSIE} ? ERB::Util.url_encode(name) : name
  end
  
  def api_request?
    %w(xml json).include? params[:format]
  end

  # Renders a warning flash if obj has unsaved attachments
  def render_attachment_warning_if_needed(obj)
    flash[:warning] = l(:warning_attachments_not_saved, obj.unsaved_attachments.size) if obj.unsaved_attachments.present?
  end

  # Rescues an invalid query statement. Just in case...
  def query_statement_invalid(exception)
    logger.error "Query::StatementInvalid: #{exception.message}" if logger
    session.delete(:query)
    sort_clear if respond_to?(:sort_clear)
    render_error "An error occurred while executing the query and has been logged. Please report this error to your Redmine administrator."
  end

  # Converts the errors on an ActiveRecord object into a common JSON format
  def object_errors_to_json(object)
    object.errors.collect do |attribute, error|
      { attribute => error }
    end.to_json
  end
  
end
