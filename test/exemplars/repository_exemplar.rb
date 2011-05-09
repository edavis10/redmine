class Repository < ActiveRecord::Base
  generator_for :type => 'Subversion'
  generator_for :url, :method => :next_url

  def self.next_url
    @last_url ||= 'file:///test/svn'
    @last_url.succ!
    @last_url
  end

end

# == Schema Information
#
# Table name: repositories
#
#  id            :integer(4)      not null, primary key
#  project_id    :integer(4)      default(0), not null
#  url           :string(255)     default(""), not null
#  login         :string(60)      default("")
#  password      :string(255)     default("")
#  root_url      :string(255)     default("")
#  type          :string(255)
#  path_encoding :string(64)
#  log_encoding  :string(64)
#

