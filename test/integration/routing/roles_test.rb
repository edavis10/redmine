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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingRolesTest < ActionController::IntegrationTest
  def test_roles
    assert_routing(
        { :method => 'get', :path => "/roles" },
        { :controller => 'roles', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/roles.xml" },
        { :controller => 'roles', :action => 'index', :format => 'xml' }
      )
    assert_routing(
        { :method => 'get', :path => "/roles/new" },
        { :controller => 'roles', :action => 'new' }
      )
    assert_routing(
        { :method => 'post', :path => "/roles" },
        { :controller => 'roles', :action => 'create' }
      )
    assert_routing(
        { :method => 'get', :path => "/roles/2/edit" },
        { :controller => 'roles', :action => 'edit', :id => '2' }
      )
    assert_routing(
        { :method => 'put', :path => "/roles/2" },
        { :controller => 'roles', :action => 'update', :id => '2' }
      )
    assert_routing(
        { :method => 'delete', :path => "/roles/2" },
        { :controller => 'roles', :action => 'destroy', :id => '2' }
      )
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method, :path => "/roles/permissions" },
          { :controller => 'roles', :action => 'permissions' }
        )
    end
  end
end
