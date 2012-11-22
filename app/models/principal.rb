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

class Principal < ActiveRecord::Base
  self.table_name = "#{table_name_prefix}users#{table_name_suffix}"

  has_many :members, :foreign_key => 'user_id', :dependent => :destroy
  has_many :memberships, :class_name => 'Member', :foreign_key => 'user_id', :include => [ :project, :roles ], :conditions => "#{Project.table_name}.status<>#{Project::STATUS_ARCHIVED}", :order => "#{Project.table_name}.name"
  has_many :projects, :through => :memberships
  has_many :issue_categories, :foreign_key => 'assigned_to_id', :dependent => :nullify

  # Groups and active users
  scope :active, :conditions => "#{Principal.table_name}.status = 1"

  scope :like, lambda {|q|
    if q.blank?
      {}
    else
      q = q.to_s
      pattern = "%#{q}%"
      sql = "LOWER(login) LIKE LOWER(:p) OR LOWER(firstname) LIKE LOWER(:p) OR LOWER(lastname) LIKE LOWER(:p) OR LOWER(mail) LIKE LOWER(:p)"
      params = {:p => pattern}
      if q =~ /^(.+)\s+(.+)$/
        a, b = "#{$1}%", "#{$2}%"
        sql << " OR (LOWER(firstname) LIKE LOWER(:a) AND LOWER(lastname) LIKE LOWER(:b)) OR (LOWER(firstname) LIKE LOWER(:b) AND LOWER(lastname) LIKE LOWER(:a))"
        params.merge!(:a => a, :b => b)
      end
      {:conditions => [sql, params]}
    end
  }

  # Principals that are members of a collection of projects
  scope :member_of, lambda {|projects|
    projects = [projects] unless projects.is_a?(Array)
    if projects.empty?
      {:conditions => "1=0"}
    else
      ids = projects.map(&:id)
      {:conditions => ["#{Principal.table_name}.status = 1 AND #{Principal.table_name}.id IN (SELECT DISTINCT user_id FROM #{Member.table_name} WHERE project_id IN (?))", ids]}
    end
  }
  # Principals that are not members of projects
  scope :not_member_of, lambda {|projects|
    projects = [projects] unless projects.is_a?(Array)
    if projects.empty?
      {:conditions => "1=0"}
    else
      ids = projects.map(&:id)
      {:conditions => ["#{Principal.table_name}.id NOT IN (SELECT DISTINCT user_id FROM #{Member.table_name} WHERE project_id IN (?))", ids]}
    end
  }

  before_create :set_default_empty_values

  def name(formatter = nil)
    to_s
  end

  def <=>(principal)
    if principal.nil?
      -1
    elsif self.class.name == principal.class.name
      self.to_s.downcase <=> principal.to_s.downcase
    else
      # groups after users
      principal.class.name <=> self.class.name
    end
  end

  protected

  # Make sure we don't try to insert NULL values (see #4632)
  def set_default_empty_values
    self.login ||= ''
    self.hashed_password ||= ''
    self.firstname ||= ''
    self.lastname ||= ''
    self.mail ||= ''
    true
  end
end
