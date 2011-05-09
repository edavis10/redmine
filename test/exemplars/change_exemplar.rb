class Change < ActiveRecord::Base
  generator_for :action => 'A'
  generator_for :path, :method => :next_path
  generator_for :changeset, :method => :generate_changeset

  def self.next_path
    @last_path ||= 'test/dir/aaa0001'
    @last_path.succ!
    @last_path
  end

  def self.generate_changeset
    Changeset.generate!
  end
end

# == Schema Information
#
# Table name: changes
#
#  id            :integer(4)      not null, primary key
#  changeset_id  :integer(4)      not null
#  action        :string(1)       default(""), not null
#  path          :text            default(""), not null
#  from_path     :text
#  from_revision :string(255)
#  revision      :string(255)
#  branch        :string(255)
#

