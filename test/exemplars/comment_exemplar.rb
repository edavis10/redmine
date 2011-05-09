class Comment < ActiveRecord::Base
  generator_for :commented, :method => :generate_news
  generator_for :author, :method => :generate_author
  generator_for :comments => 'What great news this is.'

  def self.generate_news
    News.generate!
  end

  def self.generate_author
    User.generate_with_protected!
  end
end

# == Schema Information
#
# Table name: comments
#
#  id             :integer(4)      not null, primary key
#  commented_type :string(30)      default(""), not null
#  commented_id   :integer(4)      default(0), not null
#  author_id      :integer(4)      default(0), not null
#  comments       :text
#  created_on     :datetime        not null
#  updated_on     :datetime        not null
#

