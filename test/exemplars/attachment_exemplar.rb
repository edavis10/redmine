class Attachment < ActiveRecord::Base
  generator_for :container, :method => :generate_project
  generator_for :file, :method => :generate_file
  generator_for :author, :method => :generate_author

  def self.generate_project
    Project.generate!
  end

  def self.generate_author
    User.generate_with_protected!
  end

  def self.generate_file
    @file = ActiveSupport::TestCase.mock_file
  end
end

# == Schema Information
#
# Table name: attachments
#
#  id             :integer(4)      not null, primary key
#  container_id   :integer(4)      default(0), not null
#  container_type :string(30)      default(""), not null
#  filename       :string(255)     default(""), not null
#  disk_filename  :string(255)     default(""), not null
#  filesize       :integer(4)      default(0), not null
#  content_type   :string(255)     default("")
#  digest         :string(40)      default(""), not null
#  downloads      :integer(4)      default(0), not null
#  author_id      :integer(4)      default(0), not null
#  created_on     :datetime
#  description    :string(255)
#

