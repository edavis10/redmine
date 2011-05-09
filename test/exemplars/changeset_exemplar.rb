class Changeset < ActiveRecord::Base
  generator_for :revision, :method => :next_revision
  generator_for :committed_on => Date.today
  generator_for :repository, :method => :generate_repository

  def self.next_revision
    @last_revision ||= '1'
    @last_revision.succ!
    @last_revision
  end

  def self.generate_repository
    Repository::Subversion.generate!
  end
end

# == Schema Information
#
# Table name: changesets
#
#  id            :integer(4)      not null, primary key
#  repository_id :integer(4)      not null
#  revision      :string(255)     not null
#  committer     :string(255)
#  committed_on  :datetime        not null
#  comments      :text
#  commit_date   :date
#  scmid         :string(255)
#  user_id       :integer(4)
#

