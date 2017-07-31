# Sample plugin controller
class ExampleController < ApplicationController
  unloadable

  layout 'base'
  before_action :find_project, :authorize
  menu_item :sample_plugin

  def say_hello
    @value = Setting.plugin_sample_plugin['sample_setting']
  end

  def say_goodbye
  end

private
  def find_project
    @project=Project.find(params[:id])
  end
end
