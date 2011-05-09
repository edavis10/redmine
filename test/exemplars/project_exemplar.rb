class Project < ActiveRecord::Base
  generator_for :name, :method => :next_name
  generator_for :identifier, :method => :next_identifier_from_object_daddy
  generator_for :enabled_modules, :method => :all_modules
  generator_for :trackers, :method => :next_tracker
  
  def self.next_name
    @last_name ||= 'Project 0'
    @last_name.succ!
    @last_name
  end

  # Project#next_identifier is defined on Redmine
  def self.next_identifier_from_object_daddy
    @last_identifier ||= 'project-0000'
    @last_identifier.succ!
    @last_identifier
  end

  def self.all_modules
    [].tap do |modules|
      Redmine::AccessControl.available_project_modules.each do |name|
        modules << EnabledModule.new(:name => name.to_s)
      end
    end
  end

  def self.next_tracker
    [Tracker.generate!]
  end
end

# == Schema Information
#
# Table name: projects
#
#  id                :integer(4)      not null, primary key
#  name              :string(255)     default(""), not null
#  description       :text
#  homepage          :string(255)     default("")
#  is_public         :boolean(1)      default(TRUE), not null
#  parent_id         :integer(4)
#  created_on        :datetime
#  updated_on        :datetime
#  identifier        :string(255)
#  status            :integer(4)      default(1), not null
#  lft               :integer(4)
#  rgt               :integer(4)
#  projects_count    :integer(4)
#  mapping_center_id :integer(4)
#

