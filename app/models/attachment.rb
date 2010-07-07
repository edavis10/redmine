# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require "digest/md5"

class Attachment < ActiveRecord::Base
  belongs_to :container, :polymorphic => true
  belongs_to :author, :class_name => "User", :foreign_key => "author_id"
  
  validates_presence_of :container, :filename, :author
  validates_length_of :filename, :maximum => 255
  validates_length_of :disk_filename, :maximum => 255

  acts_as_event :title => :filename,
                :url => Proc.new {|o| {:controller => 'attachments', :action => 'download', :id => o.id, :filename => o.filename}}

  acts_as_activity_provider :type => 'files',
                            :permission => :view_files,
                            :author_key => :author_id,
                            :find_options => {:select => "#{Attachment.table_name}.*", 
                                              :joins => "LEFT JOIN #{Version.table_name} ON #{Attachment.table_name}.container_type='Version' AND #{Version.table_name}.id = #{Attachment.table_name}.container_id " +
                                                        "LEFT JOIN #{Project.table_name} ON #{Version.table_name}.project_id = #{Project.table_name}.id OR ( #{Attachment.table_name}.container_type='Project' AND #{Attachment.table_name}.container_id = #{Project.table_name}.id )"}
  
  acts_as_activity_provider :type => 'documents',
                            :permission => :view_documents,
                            :author_key => :author_id,
                            :find_options => {:select => "#{Attachment.table_name}.*", 
                                              :joins => "LEFT JOIN #{Document.table_name} ON #{Attachment.table_name}.container_type='Document' AND #{Document.table_name}.id = #{Attachment.table_name}.container_id " +
                                                        "LEFT JOIN #{Project.table_name} ON #{Document.table_name}.project_id = #{Project.table_name}.id"}

  cattr_accessor :storage_path
  @@storage_path = "#{RAILS_ROOT}/files"
  
  def validate
    if self.filesize > Setting.attachment_max_size.to_i.kilobytes
      errors.add(:base, :too_long, :count => Setting.attachment_max_size.to_i.kilobytes)
    end
  end

  def file=(incoming_file)
    unless incoming_file.nil?
      @temp_file = incoming_file
      if @temp_file.size > 0
        self.filename = sanitize_filename(@temp_file.original_filename)
        self.disk_filename = Attachment.disk_filename(filename)
        self.content_type = @temp_file.content_type.to_s.chomp
        if content_type.blank?
          self.content_type = Redmine::MimeType.of(filename)
        end
        self.filesize = @temp_file.size
      end
    end
  end
	
  def file
    nil
  end

  # Copies the temporary file to its final location
  # and computes its MD5 hash
  def before_save
    if @temp_file && (@temp_file.size > 0)
      logger.debug("saving '#{self.diskfile}'")
      md5 = Digest::MD5.new
      File.open(diskfile, "wb") do |f| 
        buffer = ""
        while (buffer = @temp_file.read(8192))
          f.write(buffer)
          md5.update(buffer)
        end
      end
      self.digest = md5.hexdigest
    end
    # Don't save the content type if it's longer than the authorized length
    if self.content_type && self.content_type.length > 255
      self.content_type = nil
    end
  end

  # Deletes file on the disk
  def after_destroy
    File.delete(diskfile) if !filename.blank? && File.exist?(diskfile)
  end

  # Returns file's location on disk
  def diskfile
    "#{@@storage_path}/#{self.disk_filename}"
  end
  
  def increment_download
    increment!(:downloads)
  end

  def project
    container.project
  end
  
  def visible?(user=User.current)
    container.attachments_visible?(user)
  end
  
  def deletable?(user=User.current)
    container.attachments_deletable?(user)
  end
  
  def image?
    self.filename =~ /\.(jpe?g|gif|png)$/i
  end
  
  def is_text?
    Redmine::MimeType.is_type?('text', filename)
  end
  
  def is_diff?
    self.filename =~ /\.(patch|diff)$/i
  end
  
  # Returns true if the file is readable
  def readable?
    File.readable?(diskfile)
  end

  # Bulk attaches a set of files to an object
  #
  # Returns a Hash of the results:
  # :files => array of the attached files
  # :unsaved => array of the files that could not be attached
  def self.attach_files(obj, attachments)
    attached = []
    if attachments && attachments.is_a?(Hash)
      attachments.each_value do |attachment|
        file = attachment['file']
        next unless file && file.size > 0
        a = Attachment.create(:container => obj, 
                              :file => file,
                              :description => attachment['description'].to_s.strip,
                              :author => User.current)

        if a.new_record?
          obj.unsaved_attachments ||= []
          obj.unsaved_attachments << a
        else
          attached << a
        end
      end
    end
    {:files => attached, :unsaved => obj.unsaved_attachments}
  end
  
private
  def sanitize_filename(value)
    # get only the filename, not the whole path
    just_filename = value.gsub(/^.*(\\|\/)/, '')
    # NOTE: File.basename doesn't work right with Windows paths on Unix
    # INCORRECT: just_filename = File.basename(value.gsub('\\\\', '/')) 

    # Finally, replace all non alphanumeric, hyphens or periods with underscore
    @filename = just_filename.gsub(/[^\w\.\-]/,'_') 
  end
  
  # Returns an ASCII or hashed filename
  def self.disk_filename(filename)
    timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
    ascii = ''
    if filename =~ %r{^[a-zA-Z0-9_\.\-]*$}
      ascii = filename
    else
      ascii = Digest::MD5.hexdigest(filename)
      # keep the extension if any
      ascii << $1 if filename =~ %r{(\.[a-zA-Z0-9]+)$}
    end
    while File.exist?(File.join(@@storage_path, "#{timestamp}_#{ascii}"))
      timestamp.succ!
    end
    "#{timestamp}_#{ascii}"
  end
end
