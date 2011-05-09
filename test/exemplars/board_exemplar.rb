class Board < ActiveRecord::Base
  generator_for :name, :method => :next_name
  generator_for :description, :method => :next_description
  generator_for :project, :method => :generate_project

  def self.next_name
    @last_name ||= 'A Forum'
    @last_name.succ!
    @last_name
  end

  def self.next_description
    @last_description ||= 'Some description here'
    @last_description.succ!
    @last_description
  end

  def self.generate_project
    Project.generate!
  end
end

# == Schema Information
#
# Table name: boards
#
#  id              :integer(4)      not null, primary key
#  project_id      :integer(4)      not null
#  name            :string(255)     default(""), not null
#  description     :string(255)
#  position        :integer(4)      default(1)
#  topics_count    :integer(4)      default(0), not null
#  messages_count  :integer(4)      default(0), not null
#  last_message_id :integer(4)
#

