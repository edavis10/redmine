class Wiki < ActiveRecord::Base
  generator_for :start_page => 'Start'
  generator_for :project, :method => :generate_project

  def self.generate_project
    Project.generate!
  end
end

# == Schema Information
#
# Table name: wikis
#
#  id         :integer(4)      not null, primary key
#  project_id :integer(4)      not null
#  start_page :string(255)     not null
#  status     :integer(4)      default(1), not null
#

