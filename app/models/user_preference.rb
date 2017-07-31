# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require 'redmine/my_page'

class UserPreference < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :user
  serialize :others

  before_save :set_others_hash, :clear_unused_block_settings

  safe_attributes 'hide_mail',
    'time_zone',
    'comments_sorting',
    'warn_on_leaving_unsaved',
    'no_self_notified',
    'textarea_font'

  TEXTAREA_FONT_OPTIONS = ['monospace', 'proportional']

  def initialize(attributes=nil, *args)
    super
    if new_record?
      unless attributes && attributes.key?(:hide_mail)
        self.hide_mail = Setting.default_users_hide_mail?
      end
      unless attributes && attributes.key?(:time_zone)
        self.time_zone = Setting.default_users_time_zone
      end
      unless attributes && attributes.key?(:no_self_notified)
        self.no_self_notified = true
      end
    end
    self.others ||= {}
  end

  def set_others_hash
    self.others ||= {}
  end

  def [](attr_name)
    if has_attribute? attr_name
      super
    else
      others ? others[attr_name] : nil
    end
  end

  def []=(attr_name, value)
    if has_attribute? attr_name
      super
    else
      h = (read_attribute(:others) || {}).dup
      h.update(attr_name => value)
      write_attribute(:others, h)
      value
    end
  end

  def comments_sorting; self[:comments_sorting] end
  def comments_sorting=(order); self[:comments_sorting]=order end

  def warn_on_leaving_unsaved; self[:warn_on_leaving_unsaved] || '1'; end
  def warn_on_leaving_unsaved=(value); self[:warn_on_leaving_unsaved]=value; end

  def no_self_notified; (self[:no_self_notified] == true || self[:no_self_notified] == '1'); end
  def no_self_notified=(value); self[:no_self_notified]=value; end

  def activity_scope; Array(self[:activity_scope]) ; end
  def activity_scope=(value); self[:activity_scope]=value ; end

  def textarea_font; self[:textarea_font] end
  def textarea_font=(value); self[:textarea_font]=value; end

  # Returns the names of groups that are displayed on user's page
  # Example:
  #   preferences.my_page_groups
  #   # => ['top', 'left, 'right']
  def my_page_groups
    Redmine::MyPage.groups
  end

  def my_page_layout
    self[:my_page_layout] ||= Redmine::MyPage.default_layout.deep_dup
  end

  def my_page_layout=(arg)
    self[:my_page_layout] = arg
  end

  def my_page_settings(block=nil)
    s = self[:my_page_settings] ||= {}
    if block
      s[block] ||= {}
    else
      s
    end
  end

  def my_page_settings=(arg)
    self[:my_page_settings] = arg
  end

  # Removes block from the user page layout
  # Example:
  #   preferences.remove_block('news')
  def remove_block(block)
    block = block.to_s.underscore
    my_page_layout.keys.each do |group|
      my_page_layout[group].delete(block)
    end
    my_page_layout
  end

  # Adds block to the user page layout
  # Returns nil if block is not valid or if it's already
  # present in the user page layout
  def add_block(block)
    block = block.to_s.underscore
    return unless Redmine::MyPage.valid_block?(block, my_page_layout.values.flatten)

    remove_block(block)
    # add it to the first group
    group = my_page_groups.first
    my_page_layout[group] ||= []
    my_page_layout[group].unshift(block)
  end

  # Sets the block order for the given group.
  # Example:
  #   preferences.order_blocks('left', ['issueswatched', 'news'])
  def order_blocks(group, blocks)
    group = group.to_s
    if Redmine::MyPage.groups.include?(group) && blocks.present?
      blocks = blocks.map(&:underscore) & my_page_layout.values.flatten
      blocks.each {|block| remove_block(block)}
      my_page_layout[group] = blocks
    end
  end

  def update_block_settings(block, settings)
    block = block.to_s
    block_settings = my_page_settings(block).merge(settings.symbolize_keys)
    my_page_settings[block] = block_settings
  end

  def clear_unused_block_settings
    blocks = my_page_layout.values.flatten
    my_page_settings.keep_if {|block, settings| blocks.include?(block)}
  end
  private :clear_unused_block_settings
end
