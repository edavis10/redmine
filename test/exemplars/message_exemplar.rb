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
