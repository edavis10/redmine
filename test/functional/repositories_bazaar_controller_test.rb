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
require 'repositories_controller'

# Re-raise errors caught by the controller.
class RepositoriesController; def rescue_action(e) raise e end; end

class RepositoriesBazaarControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :repositories, :enabled_modules

  # No '..' in the repository path
  REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/bazaar_repository'

  def setup
    @controller = RepositoriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    Repository::Bazaar.create(:project => Project.find(3), :url => REPOSITORY_PATH)
  end
  
  if File.directory?(REPOSITORY_PATH)
    def test_show
      get :show, :id => 3
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_not_nil assigns(:changesets)
    end
    
    def test_browse_root
      get :show, :id => 3
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 2, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'directory' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'root_level.txt' && e.kind == 'file'}
    end
    
    def test_browse_directory
      get :show, :id => 3, :path => ['directory']
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ["config.txt", "edit.png", "second_file.txt", "source2.txt"], assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'edit.png'}
      assert_not_nil entry
      assert_equal 'file', entry.kind
      assert_equal 'directory/edit.png', entry.path
    end
    
    def test_browse_at_given_revision
      get :show, :id => 3, :path => [], :rev => 'johndoe@no.server-20100927142810-5hx3443dk9mdbs3t'
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['directory', 'mainfile.txt'], assigns(:entries).collect(&:name)
    end
    
    def test_changes
      get :changes, :id => 3, :path => ['root_level.txt']
      assert_response :success
      assert_template 'changes'
      assert_tag :tag => 'h2', :content => 'root_level.txt'
    end
    
    def test_entry_show
      get :entry, :id => 3, :path => ['directory', 'second_file.txt']
      assert_response :success
      assert_template 'entry'
      # Line 2
      assert_tag :tag => 'th',
                 :content => /2/,
                 :attributes => { :class => /line-num/ },
                 :sibling => { :tag => 'td', :content => /More code from/ }
    end
    
    def test_entry_download
      get :entry, :id => 3, :path => ['directory', 'second_file.txt'], :format => 'raw'
      assert_response :success
      # File content
      assert @response.body.include?('More code from')
    end
  
    def test_directory_entry
      get :entry, :id => 3, :path => ['directory']
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'directory', assigns(:entry).name
    end

    def test_diff
      # Full diff of changeset 3
      get :diff, :id => 3, :rev => 'johndoe@no.server-20100927142810-5hx3443dk9mdbs3t'
      assert_response :success
      assert_template 'diff'
      # Line 22 removed
      assert_tag :tag => 'th',
                 :content => /2/,
                 :sibling => { :tag => 'td', 
                               :attributes => { :class => /diff_in/ },
                               :content => /Added another line to the file/ }
    end
    
    def test_annotate
      get :annotate, :id => 3, :path => ['root_level.txt']
      assert_response :success
      assert_template 'annotate'
      # Line 2, revision 3
      assert_tag :tag => 'th', :content => /2/,
                 :sibling => { :tag => 'td', :content => /5/, :child => { :tag => 'a', :content => /second@no\.server\-20100927143241\-aknlenpvde342upv/ } },
                 :sibling => { :tag => 'td', :content => /second@no\.server/ },
                 :sibling => { :tag => 'td', :content => /The above line is incorrect/ }
    end
  else
    puts "Bazaar test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
