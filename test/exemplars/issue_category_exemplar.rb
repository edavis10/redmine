class IssueCategory < ActiveRecord::Base
  generator_for :name, :method => :next_name
  
  def self.next_name
    @last_name ||= 'Category 0001'
    @last_name.succ!
    @last_name
  end
end

# == Schema Information
#
# Table name: issue_categories
#
#  id             :integer(4)      not null, primary key
#  project_id     :integer(4)      default(0), not null
#  name           :string(30)      default(""), not null
#  assigned_to_id :integer(4)
#

