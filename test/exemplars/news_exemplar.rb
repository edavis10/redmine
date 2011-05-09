class News < ActiveRecord::Base
  generator_for :title, :method => :next_title
  generator_for :description, :method => :next_description

  def self.next_title
    @last_title ||= 'A New Item'
    @last_title.succ!
    @last_title
  end

  def self.next_description
    @last_description ||= 'Some content here'
    @last_description.succ!
    @last_description
  end
end

# == Schema Information
#
# Table name: news
#
#  id             :integer(4)      not null, primary key
#  project_id     :integer(4)
#  title          :string(60)      default(""), not null
#  summary        :string(255)     default("")
#  description    :text
#  author_id      :integer(4)      default(0), not null
#  created_on     :datetime
#  comments_count :integer(4)      default(0), not null
#

