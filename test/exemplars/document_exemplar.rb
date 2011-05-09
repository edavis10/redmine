class Document < ActiveRecord::Base
  generator_for :title, :method => :next_title

  def self.next_title
    @last_title ||= 'Document001'
    @last_title.succ!
    @last_title
  end
end

# == Schema Information
#
# Table name: documents
#
#  id          :integer(4)      not null, primary key
#  project_id  :integer(4)      default(0), not null
#  category_id :integer(4)      default(0), not null
#  title       :string(60)      default(""), not null
#  description :text
#  created_on  :datetime
#

