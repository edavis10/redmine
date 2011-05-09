class IssueStatus < ActiveRecord::Base
  generator_for :name, :method => :next_name

  def self.next_name
    @last_name ||= 'Status 0'
    @last_name.succ!
    @last_name
  end
end

# == Schema Information
#
# Table name: issue_statuses
#
#  id                 :integer(4)      not null, primary key
#  name               :string(30)      default(""), not null
#  is_closed          :boolean(1)      default(FALSE), not null
#  is_default         :boolean(1)      default(FALSE), not null
#  position           :integer(4)      default(1)
#  default_done_ratio :integer(4)
#

