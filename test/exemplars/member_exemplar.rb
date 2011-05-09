class Member < ActiveRecord::Base
  generator_for :roles, :method => :generate_roles
  generator_for :principal, :method => :generate_user

  def self.generate_roles
    [Role.generate!]
  end

  def self.generate_user
    User.generate_with_protected!
  end
end

# == Schema Information
#
# Table name: members
#
#  id                :integer(4)      not null, primary key
#  user_id           :integer(4)      default(0), not null
#  project_id        :integer(4)      default(0), not null
#  created_on        :datetime
#  mail_notification :boolean(1)      default(FALSE), not null
#  role_id           :integer(4)
#

