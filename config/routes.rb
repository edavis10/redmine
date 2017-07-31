# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

Rails.application.routes.draw do
  root :to => 'welcome#index', :as => 'home'

  match 'login', :to => 'account#login', :as => 'signin', :via => [:get, :post]
  match 'logout', :to => 'account#logout', :as => 'signout', :via => [:get, :post]
  match 'account/register', :to => 'account#register', :via => [:get, :post], :as => 'register'
  match 'account/lost_password', :to => 'account#lost_password', :via => [:get, :post], :as => 'lost_password'
  match 'account/activate', :to => 'account#activate', :via => :get
  get 'account/activation_email', :to => 'account#activation_email', :as => 'activation_email'

  match '/news/preview', :controller => 'previews', :action => 'news', :as => 'preview_news', :via => [:get, :post, :put, :patch]
  match '/issues/preview/new/:project_id', :to => 'previews#issue', :as => 'preview_new_issue', :via => [:get, :post, :put, :patch]
  match '/issues/preview/edit/:id', :to => 'previews#issue', :as => 'preview_edit_issue', :via => [:get, :post, :put, :patch]
  match '/issues/preview', :to => 'previews#issue', :as => 'preview_issue', :via => [:get, :post, :put, :patch]

  match 'projects/:id/wiki', :to => 'wikis#edit', :via => :post
  match 'projects/:id/wiki/destroy', :to => 'wikis#destroy', :via => [:get, :post]

  match 'boards/:board_id/topics/new', :to => 'messages#new', :via => [:get, :post], :as => 'new_board_message'
  get 'boards/:board_id/topics/:id', :to => 'messages#show', :as => 'board_message'
  match 'boards/:board_id/topics/quote/:id', :to => 'messages#quote', :via => [:get, :post]
  get 'boards/:board_id/topics/:id/edit', :to => 'messages#edit'

  post 'boards/:board_id/topics/preview', :to => 'messages#preview', :as => 'preview_board_message'
  post 'boards/:board_id/topics/:id/replies', :to => 'messages#reply'
  post 'boards/:board_id/topics/:id/edit', :to => 'messages#edit'
  post 'boards/:board_id/topics/:id/destroy', :to => 'messages#destroy'

  # Misc issue routes. TODO: move into resources
  match '/issues/auto_complete', :to => 'auto_completes#issues', :via => :get, :as => 'auto_complete_issues'
  match '/issues/context_menu', :to => 'context_menus#issues', :as => 'issues_context_menu', :via => [:get, :post]
  match '/issues/changes', :to => 'journals#index', :as => 'issue_changes', :via => :get
  match '/issues/:id/quoted', :to => 'journals#new', :id => /\d+/, :via => :post, :as => 'quoted_issue'

  resources :journals, :only => [:edit, :update] do
    member do
      get 'diff'
    end
  end

  get '/projects/:project_id/issues/gantt', :to => 'gantts#show', :as => 'project_gantt'
  get '/issues/gantt', :to => 'gantts#show'

  get '/projects/:project_id/issues/calendar', :to => 'calendars#show', :as => 'project_calendar'
  get '/issues/calendar', :to => 'calendars#show'

  get 'projects/:id/issues/report', :to => 'reports#issue_report', :as => 'project_issues_report'
  get 'projects/:id/issues/report/:detail', :to => 'reports#issue_report_details', :as => 'project_issues_report_details'

  get   '/issues/imports/new', :to => 'imports#new', :as => 'new_issues_import'
  post  '/imports', :to => 'imports#create', :as => 'imports'
  get   '/imports/:id', :to => 'imports#show', :as => 'import'
  match '/imports/:id/settings', :to => 'imports#settings', :via => [:get, :post], :as => 'import_settings'
  match '/imports/:id/mapping', :to => 'imports#mapping', :via => [:get, :post], :as => 'import_mapping'
  match '/imports/:id/run', :to => 'imports#run', :via => [:get, :post], :as => 'import_run'

  match 'my/account', :controller => 'my', :action => 'account', :via => [:get, :post]
  match 'my/account/destroy', :controller => 'my', :action => 'destroy', :via => [:get, :post]
  match 'my/page', :controller => 'my', :action => 'page', :via => :get
  post 'my/page', :to => 'my#update_page'
  match 'my', :controller => 'my', :action => 'index', :via => :get # Redirects to my/page
  get 'my/api_key', :to => 'my#show_api_key', :as => 'my_api_key'
  post 'my/api_key', :to => 'my#reset_api_key'
  post 'my/rss_key', :to => 'my#reset_rss_key', :as => 'my_rss_key'
  match 'my/password', :controller => 'my', :action => 'password', :via => [:get, :post]
  match 'my/add_block', :controller => 'my', :action => 'add_block', :via => :post
  match 'my/remove_block', :controller => 'my', :action => 'remove_block', :via => :post
  match 'my/order_blocks', :controller => 'my', :action => 'order_blocks', :via => :post

  resources :users do
    resources :memberships, :controller => 'principal_memberships'
    resources :email_addresses, :only => [:index, :create, :update, :destroy]
  end

  post 'watchers/watch', :to => 'watchers#watch', :as => 'watch'
  delete 'watchers/watch', :to => 'watchers#unwatch'
  get 'watchers/new', :to => 'watchers#new', :as => 'new_watchers'
  post 'watchers', :to => 'watchers#create'
  post 'watchers/append', :to => 'watchers#append'
  delete 'watchers', :to => 'watchers#destroy'
  get 'watchers/autocomplete_for_user', :to => 'watchers#autocomplete_for_user'
  # Specific routes for issue watchers API
  post 'issues/:object_id/watchers', :to => 'watchers#create', :object_type => 'issue'
  delete 'issues/:object_id/watchers/:user_id' => 'watchers#destroy', :object_type => 'issue'

  resources :projects do
    collection do
      get 'autocomplete'
    end

    member do
      get 'settings(/:tab)', :action => 'settings', :as => 'settings'
      post 'archive'
      post 'unarchive'
      post 'close'
      post 'reopen'
      match 'copy', :via => [:get, :post]
    end

    shallow do
      resources :memberships, :controller => 'members' do
        collection do
          get 'autocomplete'
        end
      end
    end

    resource :enumerations, :controller => 'project_enumerations', :only => [:update, :destroy]

    get 'issues/:copy_from/copy', :to => 'issues#new', :as => 'copy_issue'
    resources :issues, :only => [:index, :new, :create]
    # Used when updating the form of a new issue
    post 'issues/new', :to => 'issues#new'

    resources :files, :only => [:index, :new, :create]

    resources :versions, :except => [:index, :show, :edit, :update, :destroy] do
      collection do
        put 'close_completed'
      end
    end
    get 'versions.:format', :to => 'versions#index'
    get 'roadmap', :to => 'versions#index', :format => false
    get 'versions', :to => 'versions#index'

    resources :news, :except => [:show, :edit, :update, :destroy]
    resources :time_entries, :controller => 'timelog', :except => [:show, :edit, :update, :destroy] do
      get 'report', :on => :collection
    end
    resources :queries, :only => [:new, :create]
    shallow do
      resources :issue_categories
    end
    resources :documents, :except => [:show, :edit, :update, :destroy]
    resources :boards
    shallow do
      resources :repositories, :except => [:index, :show] do
        member do
          match 'committers', :via => [:get, :post]
        end
      end
    end
  
    match 'wiki/index', :controller => 'wiki', :action => 'index', :via => :get
    resources :wiki, :except => [:index, :create], :as => 'wiki_page' do
      member do
        get 'rename'
        post 'rename'
        get 'history'
        get 'diff'
        match 'preview', :via => [:post, :put, :patch]
        post 'protect'
        post 'add_attachment'
      end
      collection do
        get 'export'
        get 'date_index'
        post 'new'
      end
    end
    match 'wiki', :controller => 'wiki', :action => 'show', :via => :get
    get 'wiki/:id/:version', :to => 'wiki#show', :constraints => {:version => /\d+/}
    delete 'wiki/:id/:version', :to => 'wiki#destroy_version'
    get 'wiki/:id/:version/annotate', :to => 'wiki#annotate'
    get 'wiki/:id/:version/diff', :to => 'wiki#diff'
  end

  resources :issues do
    member do
      # Used when updating the form of an existing issue
      patch 'edit', :to => 'issues#edit'
    end
    collection do
      match 'bulk_edit', :via => [:get, :post]
      post 'bulk_update'
    end
    resources :time_entries, :controller => 'timelog', :only => [:new, :create]
    shallow do
      resources :relations, :controller => 'issue_relations', :only => [:index, :show, :create, :destroy]
    end
  end
  # Used when updating the form of a new issue outside a project
  post '/issues/new', :to => 'issues#new'
  match '/issues', :controller => 'issues', :action => 'destroy', :via => :delete

  resources :queries, :except => [:show]
  get '/queries/filter', :to => 'queries#filter', :as => 'queries_filter'

  resources :news, :only => [:index, :show, :edit, :update, :destroy]
  match '/news/:id/comments', :to => 'comments#create', :via => :post
  match '/news/:id/comments/:comment_id', :to => 'comments#destroy', :via => :delete

  resources :versions, :only => [:show, :edit, :update, :destroy] do
    post 'status_by', :on => :member
  end

  resources :documents, :only => [:show, :edit, :update, :destroy] do
    post 'add_attachment', :on => :member
  end

  match '/time_entries/context_menu', :to => 'context_menus#time_entries', :as => :time_entries_context_menu, :via => [:get, :post]

  resources :time_entries, :controller => 'timelog', :except => :destroy do
    member do
      # Used when updating the edit form of an existing time entry
      patch 'edit', :to => 'timelog#edit'
    end
    collection do
      get 'report'
      get 'bulk_edit'
      post 'bulk_update'
    end
  end
  match '/time_entries/:id', :to => 'timelog#destroy', :via => :delete, :id => /\d+/
  # TODO: delete /time_entries for bulk deletion
  match '/time_entries/destroy', :to => 'timelog#destroy', :via => :delete
  # Used to update the new time entry form
  post '/time_entries/new', :to => 'timelog#new'

  get 'projects/:id/activity', :to => 'activities#index', :as => :project_activity
  get 'activity', :to => 'activities#index'

  # repositories routes
  get 'projects/:id/repository/:repository_id/statistics', :to => 'repositories#stats'
  get 'projects/:id/repository/:repository_id/graph', :to => 'repositories#graph'

  get 'projects/:id/repository/:repository_id/revisions/:rev', :to => 'repositories#revision'
  get 'projects/:id/repository/:repository_id/revision', :to => 'repositories#revision'
  post   'projects/:id/repository/:repository_id/revisions/:rev/issues', :to => 'repositories#add_related_issue'
  delete 'projects/:id/repository/:repository_id/revisions/:rev/issues/:issue_id', :to => 'repositories#remove_related_issue'
  get 'projects/:id/repository/:repository_id/revisions', :to => 'repositories#revisions'
  %w(browse show entry raw annotate diff).each do |action|
    get "projects/:id/repository/:repository_id/revisions/:rev/#{action}(/*path)",
        :controller => 'repositories',
        :action => action,
        :format => 'html',
        :constraints => {:rev => /[a-z0-9\.\-_]+/, :path => /.*/}
  end

  get 'projects/:id/repository/statistics', :to => 'repositories#stats'
  get 'projects/:id/repository/graph', :to => 'repositories#graph'

  get 'projects/:id/repository/revisions', :to => 'repositories#revisions'
  get 'projects/:id/repository/revisions/:rev', :to => 'repositories#revision'
  get 'projects/:id/repository/revision', :to => 'repositories#revision'
  post   'projects/:id/repository/revisions/:rev/issues', :to => 'repositories#add_related_issue'
  delete 'projects/:id/repository/revisions/:rev/issues/:issue_id', :to => 'repositories#remove_related_issue'
  %w(browse show entry raw annotate diff).each do |action|
    get "projects/:id/repository/revisions/:rev/#{action}(/*path)",
        :controller => 'repositories',
        :action => action,
        :format => 'html',
        :constraints => {:rev => /[a-z0-9\.\-_]+/, :path => /.*/}
  end
  %w(browse entry raw changes annotate diff).each do |action|
    get "projects/:id/repository/:repository_id/#{action}(/*path)",
        :controller => 'repositories',
        :action => action,
        :format => 'html',
        :constraints => {:path => /.*/}
  end
  %w(browse entry raw changes annotate diff).each do |action|
    get "projects/:id/repository/#{action}(/*path)",
        :controller => 'repositories',
        :action => action,
        :format => 'html',
        :constraints => {:path => /.*/}
  end

  get 'projects/:id/repository/:repository_id/show/*path', :to => 'repositories#show', :format => 'html', :constraints => {:path => /.*/}
  get 'projects/:id/repository/show/*path', :to => 'repositories#show', :format => 'html', :constraints => {:path => /.*/}

  get 'projects/:id/repository/:repository_id', :to => 'repositories#show', :path => nil
  get 'projects/:id/repository', :to => 'repositories#show', :path => nil

  # additional routes for having the file name at the end of url
  get 'attachments/:id/:filename', :to => 'attachments#show', :id => /\d+/, :filename => /.*/, :as => 'named_attachment', :format => 'html'
  get 'attachments/download/:id/:filename', :to => 'attachments#download', :id => /\d+/, :filename => /.*/, :as => 'download_named_attachment'
  get 'attachments/download/:id', :to => 'attachments#download', :id => /\d+/
  get 'attachments/thumbnail/:id(/:size)', :to => 'attachments#thumbnail', :id => /\d+/, :size => /\d+/, :as => 'thumbnail'
  resources :attachments, :only => [:show, :update, :destroy]
  get 'attachments/:object_type/:object_id/edit', :to => 'attachments#edit_all', :as => :object_attachments_edit
  patch 'attachments/:object_type/:object_id', :to => 'attachments#update_all', :as => :object_attachments

  resources :groups do
    resources :memberships, :controller => 'principal_memberships'
    member do
      get 'autocomplete_for_user'
    end
  end

  get 'groups/:id/users/new', :to => 'groups#new_users', :id => /\d+/, :as => 'new_group_users'
  post 'groups/:id/users', :to => 'groups#add_users', :id => /\d+/, :as => 'group_users'
  delete 'groups/:id/users/:user_id', :to => 'groups#remove_user', :id => /\d+/, :as => 'group_user'

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
  resources :custom_fields, :except => :show do
    resources :enumerations, :controller => 'custom_field_enumerations', :except => [:show, :new, :edit]
    put 'enumerations', :to => 'custom_field_enumerations#update_each'
  end
  resources :roles do
    collection do
      match 'permissions', :via => [:get, :post]
    end
  end
  resources :enumerations, :except => :show
  match 'enumerations/:type', :to => 'enumerations#index', :via => :get

  get 'projects/:id/search', :controller => 'search', :action => 'index'
  get 'search', :controller => 'search', :action => 'index'


  get  'mail_handler', :to => 'mail_handler#new'
  post 'mail_handler', :to => 'mail_handler#index'

  get 'admin', :to => 'admin#index'
  get 'admin/projects', :to => 'admin#projects'
  get 'admin/plugins', :to => 'admin#plugins'
  get 'admin/info', :to => 'admin#info'
  post 'admin/test_email', :to => 'admin#test_email', :as => 'test_email'
  post 'admin/default_configuration', :to => 'admin#default_configuration'

  resources :auth_sources do
    member do
      get 'test_connection', :as => 'try_connection'
    end
    collection do
      get 'autocomplete_for_new_user'
    end
  end

  match 'workflows', :controller => 'workflows', :action => 'index', :via => :get
  match 'workflows/edit', :controller => 'workflows', :action => 'edit', :via => [:get, :post]
  match 'workflows/permissions', :controller => 'workflows', :action => 'permissions', :via => [:get, :post]
  match 'workflows/copy', :controller => 'workflows', :action => 'copy', :via => [:get, :post]
  match 'settings', :controller => 'settings', :action => 'index', :via => :get
  match 'settings/edit', :controller => 'settings', :action => 'edit', :via => [:get, :post]
  match 'settings/plugin/:id', :controller => 'settings', :action => 'plugin', :via => [:get, :post], :as => 'plugin_settings'

  match 'sys/projects', :to => 'sys#projects', :via => :get
  match 'sys/projects/:id/repository', :to => 'sys#create_project_repository', :via => :post
  match 'sys/fetch_changesets', :to => 'sys#fetch_changesets', :via => [:get, :post]

  match 'uploads', :to => 'attachments#upload', :via => :post

  get 'robots', :to => 'welcome#robots'

  Dir.glob File.expand_path("#{Redmine::Plugin.directory}/*") do |plugin_dir|
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
