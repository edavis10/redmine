# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class IssuePriorityTest < ActiveSupport::TestCase
  fixtures :enumerations, :issues

  def test_should_be_an_enumeration
    assert IssuePriority.ancestors.include?(Enumeration)
  end
  
  def test_objects_count
    # low priority
    assert_equal 6, IssuePriority.find(4).objects_count
    # urgent
    assert_equal 0, IssuePriority.find(7).objects_count
  end

  def test_option_name
    assert_equal :enumeration_issue_priorities, IssuePriority.new.option_name
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

