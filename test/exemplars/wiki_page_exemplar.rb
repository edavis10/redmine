class WikiPage < ActiveRecord::Base
  generator_for :title, :method => :next_title
  generator_for :wiki, :method => :generate_wiki

  def self.next_title
    @last_title ||= 'AWikiPage'
    @last_title.succ!
    @last_title
  end

  def self.generate_wiki
    Wiki.generate!
  end
end

# == Schema Information
#
# Table name: wiki_pages
#
#  id         :integer(4)      not null, primary key
#  wiki_id    :integer(4)      not null
#  title      :string(255)     not null
#  created_on :datetime        not null
#  protected  :boolean(1)      default(FALSE), not null
#  parent_id  :integer(4)
#

