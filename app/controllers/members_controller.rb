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

class MembersController < ApplicationController
  model_object Member
  before_filter :find_model_object, :except => [:index, :create, :autocomplete]
  before_filter :find_project_from_association, :except => [:index, :create, :autocomplete]
  before_filter :find_project_by_project_id, :only => [:index, :create, :autocomplete]
  before_filter :authorize
  accept_api_auth :index, :show, :create, :update, :destroy

  def index
    @offset, @limit = api_offset_and_limit
    @member_count = @project.member_principals.count
    @member_pages = Paginator.new self, @member_count, @limit, params['page']
    @offset ||= @member_pages.current.offset
    @members =  @project.member_principals.all(
      :order => "#{Member.table_name}.id",
      :limit  =>  @limit,
      :offset =>  @offset
    )

    respond_to do |format|
      format.html { head 406 }
      format.api
    end
  end

  def show
    respond_to do |format|
      format.html { head 406 }
      format.api
    end
  end

  def create
    members = []
    if params[:membership]
      if params[:membership][:user_ids]
        attrs = params[:membership].dup
        user_ids = attrs.delete(:user_ids)
        user_ids.each do |user_id|
          members << Member.new(:role_ids => params[:membership][:role_ids], :user_id => user_id)
        end
      else
        members << Member.new(:role_ids => params[:membership][:role_ids], :user_id => params[:membership][:user_id])
      end
      @project.members << members
    end

    respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'members', :id => @project }
      format.js { @members = members }
      format.api {
        @member = members.first
        if @member.valid?
          render :action => 'show', :status => :created, :location => membership_url(@member)
        else
          render_validation_errors(@member)
        end
      }
    end
  end

  def update
    if params[:membership]
      @member.role_ids = params[:membership][:role_ids]
    end
    saved = @member.save
    respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'members', :id => @project }
      format.js
      format.api {
        if saved
          render_api_ok
        else
          render_validation_errors(@member)
        end
      }
    end
  end

  def destroy
    if request.delete? && @member.deletable?
      @member.destroy
    end
    respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'members', :id => @project }
      format.js
      format.api {
        if @member.destroyed?
          render_api_ok
        else
          head :unprocessable_entity
        end
      }
    end
  end

  def autocomplete
    @principals = Principal.active.not_member_of(@project).like(params[:q]).all(:limit => 100)
    render :layout => false
  end
end
