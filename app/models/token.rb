# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class Token < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :value

  before_create :delete_previous_tokens, :generate_new_token

  @@validity_time = 1.day

  def generate_new_token
    self.value = Token.generate_token_value
  end

  # Return true if token has expired
  def expired?
    return Time.now > self.created_on + @@validity_time
  end

  # Delete all expired tokens
  def self.destroy_expired
    Token.delete_all ["action NOT IN (?) AND created_on < ?", ['feeds', 'api'], Time.now - @@validity_time]
  end

  # Returns the active user who owns the key for the given action
  def self.find_active_user(action, key, validity_days=nil)
    action = action.to_s
    key = key.to_s
    return nil unless action.present? && !key.match('\A[a-zA-Z0-9]+\Z').nil?

    token = find_by_action_and_value(action, key)
    if token && token.user && token.user.active?
      if validity_days.nil? || (token.created_on > validity_days.days.ago)
        token.user
      end
    end
  end

  def self.generate_token_value
    Redmine::Utils.random_hex(20)
  end

  private

  # Removes obsolete tokens (same user and action)
  def delete_previous_tokens
    if user
      Token.delete_all(['user_id = ? AND action = ?', user.id, action])
    end
  end
end
