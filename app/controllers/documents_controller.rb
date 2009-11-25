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

class DocumentsController < ApplicationController
  default_search_scope :documents
  before_filter :find_project, :only => [:index, :new]
  before_filter :find_document, :except => [:index, :new]
  before_filter :authorize
  
  helper :attachments
  
  def index
    @sort_by = %w(category date title author).include?(params[:sort_by]) ? params[:sort_by] : 'category'
    documents = @project.documents.find :all, :include => [:attachments, :category]
    case @sort_by
    when 'date'
      @grouped = documents.group_by {|d| d.created_on.to_date }
    when 'title'
      @grouped = documents.group_by {|d| d.title.first.upcase}
    when 'author'
      @grouped = documents.select{|d| d.attachments.any?}.group_by {|d| d.attachments.last.author}
    else
      @grouped = documents.group_by(&:category)
    end
    @document = @project.documents.build
    render :layout => false if request.xhr?
  end
  
  def show
    @attachments = @document.attachments.find(:all, :order => "created_on DESC")
  end

  def new
    @document = @project.documents.build(params[:document])    
    if request.post? and @document.save	
      attach_files(@document, params[:attachments])
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :project_id => @project
    end
  end
  
  def edit
    @categories = DocumentCategory.all
    if request.post? and @document.update_attributes(params[:document])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'show', :id => @document
    end
  end  

  def destroy
    @document.destroy
    redirect_to :controller => 'documents', :action => 'index', :project_id => @project
  end
  
  def add_attachment
    attachments = attach_files(@document, params[:attachments])
    Mailer.deliver_attachments_added(attachments) if !attachments.empty? && Setting.notified_events.include?('document_added')
    redirect_to :action => 'show', :id => @document
  end

private
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_document
    @document = Document.find(params[:id])
    @project = @document.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
