class FilesController < ApplicationController
  menu_item :files

  before_filter :find_project
  before_filter :authorize

  helper :sort
  include SortHelper

  def index
    sort_init 'filename', 'asc'
    sort_update 'filename' => "#{Attachment.table_name}.filename",
                'created_on' => "#{Attachment.table_name}.created_on",
                'size' => "#{Attachment.table_name}.filesize",
                'downloads' => "#{Attachment.table_name}.downloads"
                
    @containers = [ Project.find(@project.id, :include => :attachments, :order => sort_clause)]
    @containers += @project.versions.find(:all, :include => :attachments, :order => sort_clause).sort.reverse
    render :layout => !request.xhr?
  end

  # TODO: split method into new (GET) and create (POST)
  def new
    if request.post?
      container = (params[:version_id].blank? ? @project : @project.versions.find_by_id(params[:version_id]))
      attachments = Attachment.attach_files(container, params[:attachments])
      render_attachment_warning_if_needed(container)

      if !attachments.empty? && Setting.notified_events.include?('file_added')
        Mailer.deliver_attachments_added(attachments[:files])
      end
      redirect_to :controller => 'files', :action => 'index', :id => @project
      return
    end
    @versions = @project.versions.sort
  end
end
