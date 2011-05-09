class Journal < ActiveRecord::Base
  generator_for :journalized, :method => :generate_issue
  generator_for :user, :method => :generate_user

  def self.generate_issue
    project = Project.generate!
    Issue.generate_for_project!(project)
  end

  def self.generate_user
    User.generate_with_protected!
  end
end

# == Schema Information
#
# Table name: journals
#
#  id               :integer(4)      not null, primary key
#  journalized_id   :integer(4)      default(0), not null
#  journalized_type :string(30)      default(""), not null
#  user_id          :integer(4)      default(0), not null
#  notes            :text
#  created_on       :datetime        not null
#

