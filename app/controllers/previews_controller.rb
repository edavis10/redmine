class PreviewsController < ApplicationController
  before_filter :find_project

  def issue
    @issue = @project.issues.find_by_id(params[:id]) unless params[:id].blank?
    if @issue
      @attachements = @issue.attachments
      @description = params[:issue] && params[:issue][:description]
      if @description && @description.gsub(/(\r?\n|\n\r?)/, "\n") == @issue.description.to_s.gsub(/(\r?\n|\n\r?)/, "\n")
        @description = nil
      end
      @notes = params[:notes]
    else
      @description = (params[:issue] ? params[:issue][:description] : nil)
    end
    render :layout => false
  end

  def news
    @text = (params[:news] ? params[:news][:description] : nil)
    render :partial => 'common/preview'
  end

  private
  
  def find_project
    project_id = (params[:issue] && params[:issue][:project_id]) || params[:project_id]
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
end
