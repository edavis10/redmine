class MemberRole < ActiveRecord::Base
  generator_for :member, :method => :generate_member
  generator_for :role, :method => :generate_role

  def self.generate_role
    Role.generate!
  end

  def self.generate_member
    Member.generate!
  end
end

# == Schema Information
#
# Table name: member_roles
#
#  id             :integer(4)      not null, primary key
#  member_id      :integer(4)      not null
#  role_id        :integer(4)      not null
#  inherited_from :integer(4)
#

