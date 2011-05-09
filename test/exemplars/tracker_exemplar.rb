class Tracker < ActiveRecord::Base
  generator_for :name, :method => :next_name

  def self.next_name
    @last_name ||= 'Tracker 0'
    @last_name.succ!
    @last_name
  end
end

# == Schema Information
#
# Table name: trackers
#
#  id            :integer(4)      not null, primary key
#  name          :string(30)      default(""), not null
#  is_in_chlog   :boolean(1)      default(FALSE), not null
#  position      :integer(4)      default(1)
#  is_in_roadmap :boolean(1)      default(TRUE), not null
#

