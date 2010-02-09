# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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

class Document < ActiveRecord::Base
  belongs_to :project
  belongs_to :category, :class_name => "DocumentCategory", :foreign_key => "category_id"
  acts_as_attachable :delete_permission => :manage_documents

  acts_as_searchable :columns => ['title', "#{table_name}.description"], :include => :project
  acts_as_event :title => Proc.new {|o| "#{l(:label_document)}: #{o.title}"},
                :author => Proc.new {|o| (a = o.attachments.find(:first, :order => "#{Attachment.table_name}.created_on ASC")) ? a.author : nil },
                :url => Proc.new {|o| {:controller => 'documents', :action => 'show', :id => o.id}}
  acts_as_activity_provider :find_options => {:include => :project}
  
  validates_presence_of :project, :title, :category
  validates_length_of :title, :maximum => 60
  
  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_documents, project)
  end
  
  def after_initialize
    if new_record?
      self.category ||= DocumentCategory.default
    end
  end
  
  def updated_on
    unless @updated_on
      a = attachments.find(:first, :order => 'created_on DESC')
      @updated_on = (a && a.created_on) || created_on
    end
    @updated_on
  end
end
