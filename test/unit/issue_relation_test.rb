# Redmine - project management software
# Copyright (C) 2006-2009  Jean-Philippe Lang
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

class IssueRelationTest < ActiveSupport::TestCase
  fixtures :issue_relations, :issues

  def test_create
    from = Issue.find(1)
    to = Issue.find(2)
    
    relation = IssueRelation.new :issue_from => from, :issue_to => to, :relation_type => IssueRelation::TYPE_PRECEDES
    assert relation.save
    relation.reload
    assert_equal IssueRelation::TYPE_PRECEDES, relation.relation_type
    assert_equal from, relation.issue_from
    assert_equal to, relation.issue_to
  end
  
  def test_follows_relation_should_be_reversed
    from = Issue.find(1)
    to = Issue.find(2)
    
    relation = IssueRelation.new :issue_from => from, :issue_to => to, :relation_type => IssueRelation::TYPE_FOLLOWS
    assert relation.save
    relation.reload
    assert_equal IssueRelation::TYPE_PRECEDES, relation.relation_type
    assert_equal to, relation.issue_from
    assert_equal from, relation.issue_to
  end
  
  def test_follows_relation_should_not_be_reversed_if_validation_fails
    from = Issue.find(1)
    to = Issue.find(2)
    
    relation = IssueRelation.new :issue_from => from, :issue_to => to, :relation_type => IssueRelation::TYPE_FOLLOWS, :delay => 'xx'
    assert !relation.save
    assert_equal IssueRelation::TYPE_FOLLOWS, relation.relation_type
    assert_equal from, relation.issue_from
    assert_equal to, relation.issue_to
  end
  
  def test_relation_type_for
    from = Issue.find(1)
    to = Issue.find(2)
    
    relation = IssueRelation.new :issue_from => from, :issue_to => to, :relation_type => IssueRelation::TYPE_PRECEDES
    assert_equal IssueRelation::TYPE_PRECEDES, relation.relation_type_for(from)
    assert_equal IssueRelation::TYPE_FOLLOWS, relation.relation_type_for(to)
  end
  
  def test_set_issue_to_dates_without_issue_to
    r = IssueRelation.new(:issue_from => Issue.new(:start_date => Date.today), :relation_type => IssueRelation::TYPE_PRECEDES, :delay => 1)
    assert_nil r.set_issue_to_dates
  end
  
  def test_set_issue_to_dates_without_issues
    r = IssueRelation.new(:relation_type => IssueRelation::TYPE_PRECEDES, :delay => 1)
    assert_nil r.set_issue_to_dates
  end
end
