# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# FileSystem adapter
# File written by Paul Rivier, at Demotera.
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

require 'redmine/scm/adapters/filesystem_adapter'

class Repository::Filesystem < Repository
  attr_protected :root_url
  validates_presence_of :url

  ATTRIBUTE_KEY_NAMES = {
      "url"          => "Root directory",
    }
  def self.human_attribute_name(attribute_key_name)
    ATTRIBUTE_KEY_NAMES[attribute_key_name] || super
  end

  def self.scm_adapter_class
    Redmine::Scm::Adapters::FilesystemAdapter
  end

  def self.scm_name
    'Filesystem'
  end

  def supports_all_revisions?
    false
  end

  def entries(path=nil, identifier=nil)
    scm.entries(path, identifier)
  end

  def fetch_changesets
    nil
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

