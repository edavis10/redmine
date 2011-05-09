class WikiRedirect < ActiveRecord::Base
  generator_for :title, :method => :next_title
  generator_for :redirects_to, :method => :next_redirects_to
  generator_for :wiki, :method => :generate_wiki

  def self.next_title
    @last_title ||= 'AWikiPage'
    @last_title.succ!
    @last_title
  end

  def self.next_redirects_to
    @last_redirect ||= '/a/path/000001'
    @last_redirect.succ!
    @last_redirect
  end

  def self.generate_wiki
    Wiki.generate!
  end
end

# == Schema Information
#
# Table name: wiki_redirects
#
#  id           :integer(4)      not null, primary key
#  wiki_id      :integer(4)      not null
#  title        :string(255)
#  redirects_to :string(255)
#  created_on   :datetime        not null
#

