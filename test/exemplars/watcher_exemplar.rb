class Watcher < ActiveRecord::Base
  generator_for :user, :method => :generate_user

  def self.generate_user
    User.generate_with_protected!
  end
end

# == Schema Information
#
# Table name: watchers
#
#  id             :integer(4)      not null, primary key
#  watchable_type :string(255)     default(""), not null
#  watchable_id   :integer(4)      default(0), not null
#  user_id        :integer(4)
#

