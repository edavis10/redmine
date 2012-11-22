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

RedmineApp::Application.routes.draw do
  root :to => 'welcome#index', :as => 'home'

  match 'login', :to => 'account#login', :as => 'signin'
  match 'logout', :to => 'account#logout', :as => 'signout'
  match 'account/register', :to => 'account#register', :via => [:get, :post], :as => 'register'
  match 'account/lost_password', :to => 'account#lost_password', :via => [:get, :post], :as => 'lost_password'
  match 'account/activate', :to => 'account#activate', :via => :get

  match '/news/preview', :controller => 'previews', :action => 'news', :as => 'preview_news'
  match '/issues/preview/new/:project_id', :to => 'previews#issue', :as => 'preview_new_issue'
  match '/issues/preview/edit/:id', :to => 'previews#issue', :as => 'preview_edit_issue'
  match '/issues/preview', :to => 'previews#issue', :as => 'preview_issue'

  match 'projects/:id/wiki', :to => 'wikis#edit', :via => :post
  match 'projects/:id/wiki/destroy', :to => 'wikis#destroy', :via => [:get, :post]

  match 'boards/:board_id/topics/new', :to => 'messages#new', :via => [:get, :post]
  get 'boards/:board_id/topics/:id', :to => 'messages#show', :as => 'board_message'
  match 'boards/:board_id/topics/quote/:id', :to => 'messages#quote', :via => [:get, :post]
  get 'boards/:board_id/topics/:id/edit', :to => 'messages#edit'

  post 'boards/:board_id/topics/preview', :to => 'messages#preview'
  post 'boards/:board_id/topics/:id/replies', :to => 'messages#reply'
  post 'boards/:board_id/topics/:id/edit', :to => 'messages#edit'
  post 'boards/:board_id/topics/:id/destroy', :to => 'messages#destroy'

  # Misc issue routes. TODO: move into resources
  match '/issues/auto_complete', :to => 'auto_completes#issues', :via => :get, :as => 'auto_complete_issues'
  match '/issues/context_menu', :to => 'context_menus#issues', :as => 'issues_context_menu'
  match '/issues/changes', :to => 'journals#index', :as => 'issue_changes'
  match '/issues/:id/quoted', :to => 'journals#new', :id => /\d+/, :via => :post, :as => 'quoted_issue'

  match '/journals/diff/:id', :to => 'journals#diff', :id => /\d+/, :via => :get
  match '/journals/edit/:id', :to => 'journals#edit', :id => /\d+/, :via => [:get, :post]

  match '/projects/:project_id/issues/gantt', :to => 'gantts#show'
  match '/issues/gantt', :to => 'gantts#show'

  match '/projects/:project_id/issues/calendar', :to => 'calendars#show'
  match '/issues/calendar', :to => 'calendars#show'

  match 'projects/:id/issues/report', :to => 'reports#issue_report', :via => :get
  match 'projects/:id/issues/report/:detail', :to => 'reports#issue_report_details', :via => :get

  match 'my/account', :controller => 'my', :action => 'account', :via => [:get, :post]
  match 'my/account/destroy', :controller => 'my', :action => 'destroy', :via => [:get, :post]
  match 'my/page', :controller => 'my', :action => 'page', :via => :get
  match 'my', :controller => 'my', :action => 'index', :via => :get # Redirects to my/page
  match 'my/reset_rss_key', :controller => 'my', :action => 'reset_rss_key', :via => :post
  match 'my/reset_api_key', :controller => 'my', :action => 'reset_api_key', :via => :post
  match 'my/password', :controller => 'my', :action => 'password', :via => [:get, :post]
  match 'my/page_layout', :controller => 'my', :action => 'page_layout', :via => :get
  match 'my/add_block', :controller => 'my', :action => 'add_block', :via => :post
  match 'my/remove_block', :controller => 'my', :action => 'remove_block', :via => :post
  match 'my/order_blocks', :controller => 'my', :action => 'order_blocks', :via => :post

  resources :users
  match 'users/:id/memberships/:membership_id', :to => 'users#edit_membership', :via => :put, :as => 'user_membership'
  match 'users/:id/memberships/:membership_id', :to => 'users#destroy_membership', :via => :delete
  match 'users/:id/memberships', :to => 'users#edit_membership', :via => :post, :as => 'user_memberships'

  match 'watchers/new', :controller=> 'watchers', :action => 'new', :via => :get
  match 'watchers', :controller=> 'watchers', :action => 'create', :via => :post
  match 'watchers/append', :controller=> 'watchers', :action => 'append', :via => :post
  match 'watchers/destroy', :controller=> 'watchers', :action => 'destroy', :via => :post
  match 'watchers/watch', :controller=> 'watchers', :action => 'watch', :via => :post
  match 'watchers/unwatch', :controller=> 'watchers', :action => 'unwatch', :via => :post
  match 'watchers/autocomplete_for_user', :controller=> 'watchers', :action => 'autocomplete_for_user', :via => :get

  match 'projects/:id/settings/:tab', :to => "projects#settings"

  resources :projects do
    member do
      get 'settings'
      post 'modules'
      post 'archive'
      post 'unarchive'
      post 'close'
      post 'reopen'
      match 'copy', :via => [:get, :post]
    end

    resources :memberships, :shallow => true, :controller => 'members', :only => [:index, :show, :create, :update, :destroy] do
      collection do
        get 'autocomplete'
      end
    end

    resource :enumerations, :controller => 'project_enumerations', :only => [:update, :destroy]

    match 'issues/:copy_from/copy', :to => 'issues#new'
    resources :issues, :only => [:index, :new, :create] do
      resources :time_entries, :controller => 'timelog' do
        collection do
          get 'report'
        end
      end
    end
    # issue form update
    match 'issues/new', :controller => 'issues', :action => 'new', :via => [:put, :post], :as => 'issue_form'

    resources :files, :only => [:index, :new, :create]

    resources :versions, :except => [:index, :show, :edit, :update, :destroy] do
      collection do
        put 'close_completed'
      end
    end
    match 'versions.:format', :to => 'versions#index'
    match 'roadmap', :to => 'versions#index', :format => false
    match 'versions', :to => 'versions#index'

    resources :news, :except => [:show, :edit, :update, :destroy]
    resources :time_entries, :controller => 'timelog' do
      get 'report', :on => :collection
    end
    resources :queries, :only => [:new, :create]
    resources :issue_categories, :shallow => true
    resources :documents, :except => [:show, :edit, :update, :destroy]
    resources :boards
    resources :repositories, :shallow => true, :except => [:index, :show] do
      member do
        match 'committers', :via => [:get, :post]
      end
    end

    match 'wiki/index', :controller => 'wiki', :action => 'index', :via => :get
    match 'wiki/:id/diff/:version/vs/:version_from', :controller => 'wiki', :action => 'diff'
    match 'wiki/:id/diff/:version', :controller => 'wiki', :action => 'diff'
    resources :wiki, :except => [:index, :new, :create] do
      member do
        get 'rename'
        post 'rename'
        get 'history'
        get 'diff'
        match 'preview', :via => [:post, :put]
        post 'protect'
        post 'add_attachment'
      end
      collection do
        get 'export'
        get 'date_index'
      end
    end
    match 'wiki', :controller => 'wiki', :action => 'show', :via => :get
    match 'wiki/:id/annotate/:version', :controller => 'wiki', :action => 'annotate'
  end

  resources :issues do
    collection do
      match 'bulk_edit', :via => [:get, :post]
      post 'bulk_update'
    end
    resources :time_entries, :controller => 'timelog' do
      collection do
        get 'report'
      end
    end
    resources :relations, :shallow => true, :controller => 'issue_relations', :only => [:index, :show, :create, :destroy]
  end
  match '/issues', :controller => 'issues', :action => 'destroy', :via => :delete

  resources :queries, :except => [:show]

  resources :news, :only => [:index, :show, :edit, :update, :destroy]
  match '/news/:id/comments', :to => 'comments#create', :via => :post
  match '/news/:id/comments/:comment_id', :to => 'comments#destroy', :via => :delete

  resources :versions, :only => [:show, :edit, :update, :destroy] do
    post 'status_by', :on => :member
  end

  resources :documents, :only => [:show, :edit, :update, :destroy] do
    post 'add_attachment', :on => :member
  end

  match '/time_entries/context_menu', :to => 'context_menus#time_entries', :as => :time_entries_context_menu

  resources :time_entries, :controller => 'timelog', :except => :destroy do
    collection do
      get 'report'
      get 'bulk_edit'
      post 'bulk_update'
    end
  end
  match '/time_entries/:id', :to => 'timelog#destroy', :via => :delete, :id => /\d+/
  # TODO: delete /time_entries for bulk deletion
  match '/time_entries/destroy', :to => 'timelog#destroy', :via => :delete

  # TODO: port to be part of the resources route(s)
  match 'projects/:id/settings/:tab', :to => 'projects#settings', :via => :get

  get 'projects/:id/activity', :to => 'activities#index'
  get 'projects/:id/activity.:format', :to => 'activities#index'
  get 'activity', :to => 'activities#index'

  # repositories routes
  get 'projects/:id/repository/:repository_id/statistics', :to => 'repositories#stats'
  get 'projects/:id/repository/:repository_id/graph', :to => 'repositories#graph'

  get 'projects/:id/repository/:repository_id/changes(/*path(.:ext))',
      :to => 'repositories#changes'

  get 'projects/:id/repository/:repository_id/revisions/:rev', :to => 'repositories#revision'
  get 'projects/:id/repository/:repository_id/revision', :to => 'repositories#revision'
  post   'projects/:id/repository/:repository_id/revisions/:rev/issues', :to => 'repositories#add_related_issue'
  delete 'projects/:id/repository/:repository_id/revisions/:rev/issues/:issue_id', :to => 'repositories#remove_related_issue'
  get 'projects/:id/repository/:repository_id/revisions', :to => 'repositories#revisions'
  get 'projects/:id/repository/:repository_id/revisions/:rev/:action(/*path(.:ext))',
      :controller => 'repositories',
      :format => false,
      :constraints => {
            :action => /(browse|show|entry|raw|annotate|diff)/,
            :rev    => /[a-z0-9\.\-_]+/
          }

  get 'projects/:id/repository/statistics', :to => 'repositories#stats'
  get 'projects/:id/repository/graph', :to => 'repositories#graph'

  get 'projects/:id/repository/changes(/*path(.:ext))',
      :to => 'repositories#changes'

  get 'projects/:id/repository/revisions', :to => 'repositories#revisions'
  get 'projects/:id/repository/revisions/:rev', :to => 'repositories#revision'
  get 'projects/:id/repository/revision', :to => 'repositories#revision'
  post   'projects/:id/repository/revisions/:rev/issues', :to => 'repositories#add_related_issue'
  delete 'projects/:id/repository/revisions/:rev/issues/:issue_id', :to => 'repositories#remove_related_issue'
  get 'projects/:id/repository/revisions/:rev/:action(/*path(.:ext))',
      :controller => 'repositories',
      :format => false,
      :constraints => {
            :action => /(browse|show|entry|raw|annotate|diff)/,
            :rev    => /[a-z0-9\.\-_]+/
          }
  get 'projects/:id/repository/:repository_id/:action(/*path(.:ext))',
      :controller => 'repositories',
      :action => /(browse|show|entry|raw|changes|annotate|diff)/
  get 'projects/:id/repository/:action(/*path(.:ext))',
      :controller => 'repositories',
      :action => /(browse|show|entry|raw|changes|annotate|diff)/

  get 'projects/:id/repository/:repository_id', :to => 'repositories#show', :path => nil
  get 'projects/:id/repository', :to => 'repositories#show', :path => nil

  # additional routes for having the file name at the end of url
  match 'attachments/:id/:filename', :controller => 'attachments', :action => 'show', :id => /\d+/, :filename => /.*/, :via => :get
  match 'attachments/download/:id/:filename', :controller => 'attachments', :action => 'download', :id => /\d+/, :filename => /.*/, :via => :get
  match 'attachments/download/:id', :controller => 'attachments', :action => 'download', :id => /\d+/, :via => :get
  match 'attachments/thumbnail/:id(/:size)', :controller => 'attachments', :action => 'thumbnail', :id => /\d+/, :via => :get, :size => /\d+/
  resources :attachments, :only => [:show, :destroy]

  resources :groups do
    member do
      get 'autocomplete_for_user'
    end
  end

  match 'groups/:id/users', :controller => 'groups', :action => 'add_users', :id => /\d+/, :via => :post, :as => 'group_users'
  match 'groups/:id/users/:user_id', :controller => 'groups', :action => 'remove_user', :id => /\d+/, :via => :delete, :as => 'group_user'
  match 'groups/destroy_membership/:id', :controller => 'groups', :action => 'destroy_membership', :id => /\d+/, :via => :post
  match 'groups/edit_membership/:id', :controller => 'groups', :action => 'edit_membership', :id => /\d+/, :via => :post

  resources :trackers, :except => :show do
    collection do
      match 'fields', :via => [:get, :post]
    end
  end
  resources :issue_statuses, :except => :show do
    collection do
      post 'update_issue_done_ratio'
    end
  end
  resources :custom_fields, :except => :show
  resources :roles, :except => :show do
    collection do
      match 'permissions', :via => [:get, :post]
    end
  end
  resources :enumerations, :except => :show

  get 'projects/:id/search', :controller => 'search', :action => 'index'
  get 'search', :controller => 'search', :action => 'index'

  match 'mail_handler', :controller => 'mail_handler', :action => 'index', :via => :post

  match 'admin', :controller => 'admin', :action => 'index', :via => :get
  match 'admin/projects', :controller => 'admin', :action => 'projects', :via => :get
  match 'admin/plugins', :controller => 'admin', :action => 'plugins', :via => :get
  match 'admin/info', :controller => 'admin', :action => 'info', :via => :get
  match 'admin/test_email', :controller => 'admin', :action => 'test_email', :via => :get
  match 'admin/default_configuration', :controller => 'admin', :action => 'default_configuration', :via => :post

  resources :auth_sources do
    member do
      get 'test_connection'
    end
  end

  match 'workflows', :controller => 'workflows', :action => 'index', :via => :get
  match 'workflows/edit', :controller => 'workflows', :action => 'edit', :via => [:get, :post]
  match 'workflows/permissions', :controller => 'workflows', :action => 'permissions', :via => [:get, :post]
  match 'workflows/copy', :controller => 'workflows', :action => 'copy', :via => [:get, :post]
  match 'settings', :controller => 'settings', :action => 'index', :via => :get
  match 'settings/edit', :controller => 'settings', :action => 'edit', :via => [:get, :post]
  match 'settings/plugin/:id', :controller => 'settings', :action => 'plugin', :via => [:get, :post]

  match 'sys/projects', :to => 'sys#projects', :via => :get
  match 'sys/projects/:id/repository', :to => 'sys#create_project_repository', :via => :post
  match 'sys/fetch_changesets', :to => 'sys#fetch_changesets', :via => :get

  match 'uploads', :to => 'attachments#upload', :via => :post

  get 'robots.txt', :to => 'welcome#robots'

  Dir.glob File.expand_path("plugins/*", Rails.root) do |plugin_dir|
    file = File.join(plugin_dir, "config/routes.rb")
    if File.exists?(file)
      begin
        instance_eval File.read(file)
      rescue Exception => e
        puts "An error occurred while loading the routes definition of #{File.basename(plugin_dir)} plugin (#{file}): #{e.message}."
        exit 1
      end
    end
  end
end
