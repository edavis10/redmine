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

class IssueCategoriesController < ApplicationController
  menu_item :settings
  model_object IssueCategory
  before_filter :find_model_object, :except => [:index, :new, :create]
  before_filter :find_project_from_association, :except => [:index, :new, :create]
  before_filter :find_project_by_project_id, :only => [:index, :new, :create]
  before_filter :authorize
  accept_api_auth :index, :show, :create, :update, :destroy
  
  def index
    respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'categories', :id => @project }
      format.api { @categories = @project.issue_categories.all }
    end
  end

  def show
    respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'categories', :id => @project }
      format.api
    end
  end

  def new
    @category = @project.issue_categories.build
    @category.safe_attributes = params[:issue_category]

    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @category = @project.issue_categories.build
    @category.safe_attributes = params[:issue_category]
    if @category.save
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_to :controller => 'projects', :action => 'settings', :tab => 'categories', :id => @project
        end
        format.js
        format.api { render :action => 'show', :status => :created, :location => issue_category_path(@category) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'new'}
        format.js   { render :action => 'new'}
        format.api { render_validation_errors(@category) }
      end
    end
  end

  def edit
  end

  def update
    @category.safe_attributes = params[:issue_category]
    if @category.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_to :controller => 'projects', :action => 'settings', :tab => 'categories', :id => @project
        }
        format.api { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api { render_validation_errors(@category) }
      end
    end
  end

  def destroy
    @issue_count = @category.issues.size
    if @issue_count == 0 || params[:todo] || api_request? 
      reassign_to = nil
      if params[:reassign_to_id] && (params[:todo] == 'reassign' || params[:todo].blank?)
        reassign_to = @project.issue_categories.find_by_id(params[:reassign_to_id])
      end
      @category.destroy(reassign_to)
      respond_to do |format|
        format.html { redirect_to :controller => 'projects', :action => 'settings', :id => @project, :tab => 'categories' }
        format.api { render_api_ok }
      end
      return
    end
    @categories = @project.issue_categories - [@category]
  end

private
  # Wrap ApplicationController's find_model_object method to set
  # @category instead of just @issue_category
  def find_model_object
    super
    @category = @object
  end
end
