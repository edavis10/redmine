class Message < ActiveRecord::Base
  generator_for :subject, :method => :next_subject
  generator_for :content, :method => :next_content
  generator_for :board, :method => :generate_board

  def self.next_subject
    @last_subject ||= 'A Message'
    @last_subject.succ!
    @last_subject
  end

  def self.next_content
    @last_content ||= 'Some content here'
    @last_content.succ!
    @last_content
  end

  def self.generate_board
    Board.generate!
  end
end

# == Schema Information
#
# Table name: messages
#
#  id            :integer(4)      not null, primary key
#  board_id      :integer(4)      not null
#  parent_id     :integer(4)
#  subject       :string(255)     default(""), not null
#  content       :text
#  author_id     :integer(4)
#  replies_count :integer(4)      default(0), not null
#  last_reply_id :integer(4)
#  created_on    :datetime        not null
#  updated_on    :datetime        not null
#  locked        :boolean(1)      default(FALSE)
#  sticky        :integer(4)      default(0)
#

