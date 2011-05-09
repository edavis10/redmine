class Role < ActiveRecord::Base
  generator_for :name, :method => :next_name

  def self.next_name
    @last_name ||= 'Role0'
    @last_name.succ!
  end
end

# == Schema Information
#
# Table name: roles
#
#  id          :integer(4)      not null, primary key
#  name        :string(30)      default(""), not null
#  position    :integer(4)      default(1)
#  assignable  :boolean(1)      default(TRUE)
#  builtin     :integer(4)      default(0), not null
#  permissions :text
#

