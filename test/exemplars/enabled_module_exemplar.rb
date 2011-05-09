class EnabledModule < ActiveRecord::Base
  generator_for :name, :method => :next_name

  def self.next_name
    @last_name ||= 'module_001'
    @last_name.succ!
    @last_name
  end

end

# == Schema Information
#
# Table name: enabled_modules
#
#  id         :integer(4)      not null, primary key
#  project_id :integer(4)
#  name       :string(255)     not null
#

