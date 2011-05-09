class WikiContent < ActiveRecord::Base
  generator_for :text => 'Some content'
  generator_for :page, :method => :generate_page

  def self.generate_page
    WikiPage.generate!
  end
end

# == Schema Information
#
# Table name: wiki_contents
#
#  id         :integer(4)      not null, primary key
#  page_id    :integer(4)      not null
#  author_id  :integer(4)
#  text       :text(2147483647
#  comments   :string(255)     default("")
#  updated_on :datetime        not null
#  version    :integer(4)      not null
#

