# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class Message < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :board
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  acts_as_tree :counter_cache => :replies_count, :order => "#{Message.table_name}.created_on ASC"
  acts_as_attachable
  belongs_to :last_reply, :class_name => 'Message', :foreign_key => 'last_reply_id'

  acts_as_searchable :columns => ['subject', 'content'],
                     :include => {:board => :project},
                     :project_key => "#{Board.table_name}.project_id",
                     :date_column => "#{table_name}.created_on"
  acts_as_event :title => Proc.new {|o| "#{o.board.name}: #{o.subject}"},
                :description => :content,
                :type => Proc.new {|o| o.parent_id.nil? ? 'message' : 'reply'},
                :url => Proc.new {|o| {:controller => 'messages', :action => 'show', :board_id => o.board_id}.merge(o.parent_id.nil? ? {:id => o.id} :
                                                                                                                                       {:id => o.parent_id, :r => o.id, :anchor => "message-#{o.id}"})}

  acts_as_activity_provider :find_options => {:include => [{:board => :project}, :author]},
                            :author_key => :author_id
  acts_as_watchable

  validates_presence_of :board, :subject, :content
  validates_length_of :subject, :maximum => 255
  validate :cannot_reply_to_locked_topic, :on => :create

  after_create :add_author_as_watcher, :reset_counters!
  after_update :update_messages_board
  after_destroy :reset_counters!

  scope :visible, lambda {|*args| { :include => {:board => :project},
                                          :conditions => Project.allowed_to_condition(args.shift || User.current, :view_messages, *args) } }

  safe_attributes 'subject', 'content'
  safe_attributes 'locked', 'sticky', 'board_id',
    :if => lambda {|message, user|
      user.allowed_to?(:edit_messages, message.project)
    }

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_messages, project)
  end

  def cannot_reply_to_locked_topic
    # Can not reply to a locked topic
    errors.add :base, 'Topic is locked' if root.locked? && self != root
  end

  def update_messages_board
    if board_id_changed?
      Message.update_all("board_id = #{board_id}", ["id = ? OR parent_id = ?", root.id, root.id])
      Board.reset_counters!(board_id_was)
      Board.reset_counters!(board_id)
    end
  end

  def reset_counters!
    if parent && parent.id
      Message.update_all({:last_reply_id => parent.children.maximum(:id)}, {:id => parent.id})
    end
    board.reset_counters!
  end

  def sticky=(arg)
    write_attribute :sticky, (arg == true || arg.to_s == '1' ? 1 : 0)
  end

  def sticky?
    sticky == 1
  end

  def project
    board.project
  end

  def editable_by?(usr)
    usr && usr.logged? && (usr.allowed_to?(:edit_messages, project) || (self.author == usr && usr.allowed_to?(:edit_own_messages, project)))
  end

  def destroyable_by?(usr)
    usr && usr.logged? && (usr.allowed_to?(:delete_messages, project) || (self.author == usr && usr.allowed_to?(:delete_own_messages, project)))
  end

  private

  def add_author_as_watcher
    Watcher.create(:watchable => self.root, :user => author)
  end
end
