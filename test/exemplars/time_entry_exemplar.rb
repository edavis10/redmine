class TimeEntry < ActiveRecord::Base
  generator_for(:spent_on) { Date.today }
  generator_for(:hours) { (rand * 10).round(2) } # 0.01 to 9.99
  generator_for :user, :method => :generate_user

  def self.generate_user
    User.generate_with_protected!
  end
  
end

# == Schema Information
#
# Table name: time_entries
#
#  id          :integer(4)      not null, primary key
#  project_id  :integer(4)      not null
#  user_id     :integer(4)      not null
#  issue_id    :integer(4)
#  hours       :float           not null
#  comments    :string(255)
#  activity_id :integer(4)      not null
#  spent_on    :date            not null
#  tyear       :integer(4)      not null
#  tmonth      :integer(4)      not null
#  tweek       :integer(4)      not null
#  created_on  :datetime        not null
#  updated_on  :datetime        not null
#  fromDate    :date
#  toDate      :date
#

