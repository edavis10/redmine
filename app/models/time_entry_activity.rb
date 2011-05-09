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

class TimeEntryActivity < Enumeration
  has_many :time_entries, :foreign_key => 'activity_id'

  OptionName = :enumeration_activities
  
  def option_name
    OptionName
  end

  def objects_count
    time_entries.count
  end

  def transfer_relations(to)
    time_entries.update_all("activity_id = #{to.id}")
  end
end

# == Schema Information
#
# Table name: enumerations
#
#  id         :integer(4)      not null, primary key
#  name       :string(30)      default(""), not null
#  position   :integer(4)      default(1)
#  is_default :boolean(1)      default(FALSE), not null
#  type       :string(255)
#  active     :boolean(1)      default(TRUE), not null
#  project_id :integer(4)
#  parent_id  :integer(4)
#  opt        :string(4)
#

