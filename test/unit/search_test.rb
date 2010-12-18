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

class SearchTest < ActiveSupport::TestCase
  fixtures :users,
           :members, 
           :member_roles,
           :projects,
           :roles,
           :enabled_modules,
           :issues,
           :trackers,
           :journals,
           :journal_details,
           :repositories,
           :changesets

  def setup
    @project = Project.find(1)
    @issue_keyword = '%unable to print recipes%'
    @issue = Issue.find(1)
    @changeset_keyword = '%very first commit%'
    @changeset = Changeset.find(100)
  end
  
  def test_search_by_anonymous
    User.current = nil
    
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert r.include?(@changeset)
    
    # Removes the :view_changesets permission from Anonymous role
    remove_permission Role.anonymous, :view_changesets
    
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert !r.include?(@changeset)
    
    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search(@issue_keyword).first
    assert !r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert !r.include?(@changeset)
  end
  
  def test_search_by_user
    User.current = User.find_by_login('rhill')
    assert User.current.memberships.empty?
    
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert r.include?(@changeset)
    
    # Removes the :view_changesets permission from Non member role
    remove_permission Role.non_member, :view_changesets
    
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert !r.include?(@changeset)
    
    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search(@issue_keyword).first
    assert !r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert !r.include?(@changeset)
  end
  
  def test_search_by_allowed_member
    User.current = User.find_by_login('jsmith')
    assert User.current.projects.include?(@project)
    
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert r.include?(@changeset)

    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert r.include?(@changeset)
  end

  def test_search_by_unallowed_member
    # Removes the :view_changesets permission from user's and non member role
    remove_permission Role.find(1), :view_changesets
    remove_permission Role.non_member, :view_changesets
    
    User.current = User.find_by_login('jsmith')
    assert User.current.projects.include?(@project)
    
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert !r.include?(@changeset)

    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search(@issue_keyword).first
    assert r.include?(@issue)
    r = Changeset.search(@changeset_keyword).first
    assert !r.include?(@changeset)
  end
  
  def test_search_issue_with_multiple_hits_in_journals
    i = Issue.find(1)
    assert_equal 2, i.journals.count(:all, :conditions => "notes LIKE '%notes%'")
    
    r = Issue.search('%notes%').first
    assert_equal 1, r.size
    assert_equal i, r.first
  end
  
  private
  
  def remove_permission(role, permission)
    role.permissions = role.permissions - [ permission ]
    role.save
  end
end
