class Issue < ActiveRecord::Base
  generator_for :subject, :method => :next_subject
  generator_for :author, :method => :next_author
  generator_for :priority, :method => :fetch_priority
  
  def self.next_subject
    @last_subject ||= 'Subject 0'
    @last_subject.succ!
    @last_subject
  end

  def self.next_author
    User.generate_with_protected!
  end

  def self.fetch_priority
    IssuePriority.first || IssuePriority.generate!
  end

end

# == Schema Information
#
# Table name: issues
#
#  id                :integer(4)      not null, primary key
#  tracker_id        :integer(4)      default(0), not null
#  project_id        :integer(4)      default(0), not null
#  subject           :string(255)     default(""), not null
#  description       :text
#  due_date          :date
#  category_id       :integer(4)
#  status_id         :integer(4)      default(0), not null
#  assigned_to_id    :integer(4)
#  priority_id       :integer(4)      default(0), not null
#  fixed_version_id  :integer(4)
#  author_id         :integer(4)      default(0), not null
#  lock_version      :integer(4)      default(0), not null
#  created_on        :datetime
#  updated_on        :datetime
#  start_date        :date
#  done_ratio        :integer(4)      default(0), not null
#  estimated_hours   :float
#  parent_id         :integer(4)
#  root_id           :integer(4)
#  lft               :integer(4)
#  rgt               :integer(4)
#  position          :integer(4)
#  story_points      :integer(4)
#  remaining_hours   :float
#  story_points_dev  :integer(4)
#  story_points_po   :integer(4)
#  mapping_center_id :integer(4)
#

