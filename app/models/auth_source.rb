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

class AuthSource < ActiveRecord::Base
  include Redmine::Ciphering
  
  has_many :users
  
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 60

  def authenticate(login, password)
  end
  
  def test_connection
  end
  
  def auth_method_name
    "Abstract"
  end
  
  def account_password
    read_ciphered_attribute(:account_password)
  end
  
  def account_password=(arg)
    write_ciphered_attribute(:account_password, arg)
  end

  def allow_password_changes?
    self.class.allow_password_changes?
  end

  # Does this auth source backend allow password changes?
  def self.allow_password_changes?
    false
  end

  # Try to authenticate a user not yet registered against available sources
  def self.authenticate(login, password)
    AuthSource.find(:all, :conditions => ["onthefly_register=?", true]).each do |source|
      begin
        logger.debug "Authenticating '#{login}' against '#{source.name}'" if logger && logger.debug?
        attrs = source.authenticate(login, password)
      rescue => e
        logger.error "Error during authentication: #{e.message}"
        attrs = nil
      end
      return attrs if attrs
    end
    return nil
  end
end

# == Schema Information
#
# Table name: auth_sources
#
#  id                :integer(4)      not null, primary key
#  type              :string(30)      default(""), not null
#  name              :string(60)      default(""), not null
#  host              :string(60)
#  port              :integer(4)
#  account           :string(255)
#  account_password  :string(255)     default("")
#  base_dn           :string(255)
#  attr_login        :string(30)
#  attr_firstname    :string(30)
#  attr_lastname     :string(30)
#  attr_mail         :string(30)
#  onthefly_register :boolean(1)      default(FALSE), not null
#  tls               :boolean(1)      default(FALSE), not null
#

