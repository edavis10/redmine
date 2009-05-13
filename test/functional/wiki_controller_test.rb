# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

require File.dirname(__FILE__) + '/../test_helper'
require 'wiki_controller'

# Re-raise errors caught by the controller.
class WikiController; def rescue_action(e) raise e end; end

class WikiControllerTest < Test::Unit::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions, :attachments
  
  def setup
    @controller = WikiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end
  
  def test_index_routing
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki'},
      :controller => 'wiki', :action => 'index', :id => '567'
    )
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki/lalala'},
      :controller => 'wiki', :action => 'index', :id => '567', :page => 'lalala'
    )
    assert_generates(
      '/projects/567/wiki',
      :controller => 'wiki', :action => 'index', :id => '567', :page => nil
    )
  end
  
  def test_show_start_page
    get :index, :id => 'ecookbook'
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'h1', :content => /CookBook documentation/

    # child_pages macro
    assert_tag :ul, :attributes => { :class => 'pages-hierarchy' },
               :child => { :tag => 'li',
                           :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/Page_with_an_inline_image' },
                                                    :content => 'Page with an inline image' } }
  end
  
  def test_show_page_with_name
    get :index, :id => 1, :page => 'Another_page'
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'h1', :content => /Another page/
    # Included page with an inline image
    assert_tag :tag => 'p', :content => /This is an inline image/
    assert_tag :tag => 'img', :attributes => { :src => '/attachments/download/3',
                                               :alt => 'This is a logo' }
  end
  
  def test_show_unexistent_page_without_edit_right
    get :index, :id => 1, :page => 'Unexistent page'
    assert_response 404
  end
  
  def test_show_unexistent_page_with_edit_right
    @request.session[:user_id] = 2
    get :index, :id => 1, :page => 'Unexistent page'
    assert_response :success
    assert_template 'edit'
  end
  
  def test_edit_routing
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki/my_page/edit'},
      :controller => 'wiki', :action => 'edit', :id => '567', :page => 'my_page'
    )
    assert_recognizes(#TODO: use PUT to page path, adjust forms accordingly
      {:controller => 'wiki', :action => 'edit', :id => '567', :page => 'my_page'},
      {:method => :post, :path => '/projects/567/wiki/my_page/edit'}
    )
  end
  
  def test_create_page
    @request.session[:user_id] = 2
    post :edit, :id => 1,
                :page => 'New page',
                :content => {:comments => 'Created the page',
                             :text => "h1. New page\n\nThis is a new page",
                             :version => 0}
    assert_redirected_to :action => 'index', :id => 'ecookbook', :page => 'New_page'
    page = Project.find(1).wiki.find_page('New page')
    assert !page.new_record?
    assert_not_nil page.content
    assert_equal 'Created the page', page.content.comments
  end
  
  def test_preview_routing
    assert_routing(
      {:method => :post, :path => '/projects/567/wiki/CookBook_documentation/preview'},
      :controller => 'wiki', :action => 'preview', :id => '567', :page => 'CookBook_documentation'
    )
  end
  
  def test_preview
    @request.session[:user_id] = 2
    xhr :post, :preview, :id => 1, :page => 'CookBook_documentation',
                                   :content => { :comments => '',
                                                 :text => 'this is a *previewed text*',
                                                 :version => 3 }
    assert_response :success
    assert_template 'common/_preview'
    assert_tag :tag => 'strong', :content => /previewed text/
  end
  
  def test_preview_new_page
    @request.session[:user_id] = 2
    xhr :post, :preview, :id => 1, :page => 'New page',
                                   :content => { :text => 'h1. New page',
                                                 :comments => '',
                                                 :version => 0 }
    assert_response :success
    assert_template 'common/_preview'
    assert_tag :tag => 'h1', :content => /New page/
  end
  
  def test_history_routing
    assert_routing(
      {:method => :get, :path => '/projects/1/wiki/CookBook_documentation/history'},
      :controller => 'wiki', :action => 'history', :id => '1', :page => 'CookBook_documentation'
    )
  end
  
  def test_history
    get :history, :id => 1, :page => 'CookBook_documentation'
    assert_response :success
    assert_template 'history'
    assert_not_nil assigns(:versions)
    assert_equal 3, assigns(:versions).size
    assert_select "input[type=submit][name=commit]"
  end

  def test_history_with_one_version
    get :history, :id => 1, :page => 'Another_page'
    assert_response :success
    assert_template 'history'
    assert_not_nil assigns(:versions)
    assert_equal 1, assigns(:versions).size
    assert_select "input[type=submit][name=commit]", false
  end
  
  def test_diff_routing
    assert_routing(
      {:method => :get, :path => '/projects/1/wiki/CookBook_documentation/diff/2/vs/1'},
      :controller => 'wiki', :action => 'diff', :id => '1', :page => 'CookBook_documentation', :version => '2', :version_from => '1'
    )
  end

  def test_diff
    get :diff, :id => 1, :page => 'CookBook_documentation', :version => 2, :version_from => 1
    assert_response :success
    assert_template 'diff'
    assert_tag :tag => 'span', :attributes => { :class => 'diff_in'},
                               :content => /updated/
  end
  
  def test_annotate_routing
    assert_routing(
      {:method => :get, :path => '/projects/1/wiki/CookBook_documentation/annotate/2'},
      :controller => 'wiki', :action => 'annotate', :id => '1', :page => 'CookBook_documentation', :version => '2'
    )
  end
  
  def test_annotate
    get :annotate, :id => 1, :page =>  'CookBook_documentation', :version => 2
    assert_response :success
    assert_template 'annotate'
    # Line 1
    assert_tag :tag => 'tr', :child => { :tag => 'th', :attributes => {:class => 'line-num'}, :content => '1' },
                             :child => { :tag => 'td', :attributes => {:class => 'author'}, :content => /John Smith/ },
                             :child => { :tag => 'td', :content => /h1\. CookBook documentation/ }
    # Line 2
    assert_tag :tag => 'tr', :child => { :tag => 'th', :attributes => {:class => 'line-num'}, :content => '2' },
                             :child => { :tag => 'td', :attributes => {:class => 'author'}, :content => /redMine Admin/ },
                             :child => { :tag => 'td', :content => /Some updated \[\[documentation\]\] here/ }
  end
  
  def test_rename_routing
    assert_routing(
      {:method => :get, :path => '/projects/22/wiki/ladida/rename'},
      :controller => 'wiki', :action => 'rename', :id => '22', :page => 'ladida'
    )
    assert_recognizes(
      #TODO: should be moved into a update action and use a PUT to the page URI
      {:controller => 'wiki', :action => 'rename', :id => '22', :page => 'ladida'},
      {:method => :post, :path => '/projects/22/wiki/ladida/rename'}
    )
  end
  
  def test_rename_with_redirect
    @request.session[:user_id] = 2
    post :rename, :id => 1, :page => 'Another_page',
                            :wiki_page => { :title => 'Another renamed page',
                                            :redirect_existing_links => 1 }
    assert_redirected_to :action => 'index', :id => 'ecookbook', :page => 'Another_renamed_page'
    wiki = Project.find(1).wiki
    # Check redirects
    assert_not_nil wiki.find_page('Another page')
    assert_nil wiki.find_page('Another page', :with_redirect => false)
  end

  def test_rename_without_redirect
    @request.session[:user_id] = 2
    post :rename, :id => 1, :page => 'Another_page',
                            :wiki_page => { :title => 'Another renamed page',
                                            :redirect_existing_links => "0" }
    assert_redirected_to :action => 'index', :id => 'ecookbook', :page => 'Another_renamed_page'
    wiki = Project.find(1).wiki
    # Check that there's no redirects
    assert_nil wiki.find_page('Another page')
  end
  
  def test_destroy_routing
    assert_recognizes(
      #TODO: should use DELETE on page URI
      {:controller => 'wiki', :action => 'destroy', :id => '22', :page => 'ladida'},
      {:method => :post, :path => 'projects/22/wiki/ladida/destroy'}
    )
  end
  
  def test_destroy_child
    @request.session[:user_id] = 2
    post :destroy, :id => 1, :page => 'Child_1'
    assert_redirected_to :action => 'special', :id => 'ecookbook', :page => 'Page_index'
  end
  
  def test_destroy_parent
    @request.session[:user_id] = 2
    assert_no_difference('WikiPage.count') do
      post :destroy, :id => 1, :page => 'Another_page'
    end
    assert_response :success
    assert_template 'destroy'
  end
  
  def test_destroy_parent_with_nullify
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -1) do
      post :destroy, :id => 1, :page => 'Another_page', :todo => 'nullify'
    end
    assert_redirected_to :action => 'special', :id => 'ecookbook', :page => 'Page_index'
    assert_nil WikiPage.find_by_id(2)
  end
  
  def test_destroy_parent_with_cascade
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -3) do
      post :destroy, :id => 1, :page => 'Another_page', :todo => 'destroy'
    end
    assert_redirected_to :action => 'special', :id => 'ecookbook', :page => 'Page_index'
    assert_nil WikiPage.find_by_id(2)
    assert_nil WikiPage.find_by_id(5)
  end
  
  def test_destroy_parent_with_reassign
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -1) do
      post :destroy, :id => 1, :page => 'Another_page', :todo => 'reassign', :reassign_to_id => 1
    end
    assert_redirected_to :action => 'special', :id => 'ecookbook', :page => 'Page_index'
    assert_nil WikiPage.find_by_id(2)
    assert_equal WikiPage.find(1), WikiPage.find_by_id(5).parent
  end
  
  def test_special_routing
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki/page_index'},
      :controller => 'wiki', :action => 'special', :id => '567', :page => 'page_index'
    )
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki/Page_Index'},
      :controller => 'wiki', :action => 'special', :id => '567', :page => 'Page_Index'
    )
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki/date_index'},
      :controller => 'wiki', :action => 'special', :id => '567', :page => 'date_index'
    )
    assert_routing(
      {:method => :get, :path => '/projects/567/wiki/export'},
      :controller => 'wiki', :action => 'special', :id => '567', :page => 'export'
    )
  end
  
  def test_page_index
    get :special, :id => 'ecookbook', :page => 'Page_index'
    assert_response :success
    assert_template 'special_page_index'
    pages = assigns(:pages)
    assert_not_nil pages
    assert_equal Project.find(1).wiki.pages.size, pages.size
    
    assert_tag :ul, :attributes => { :class => 'pages-hierarchy' },
                    :child => { :tag => 'li', :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/CookBook_documentation' },
                                              :content => 'CookBook documentation' },
                                :child => { :tag => 'ul',
                                            :child => { :tag => 'li',
                                                        :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/Page_with_an_inline_image' },
                                                                                 :content => 'Page with an inline image' } } } },
                    :child => { :tag => 'li', :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/Another_page' },
                                                                       :content => 'Another page' } }
  end
  
  def test_not_found
    get :index, :id => 999
    assert_response 404
  end
  
  def test_protect_routing
    assert_routing(
      {:method => :post, :path => 'projects/22/wiki/ladida/protect'},
      {:controller => 'wiki', :action => 'protect', :id => '22', :page => 'ladida'}
    )
  end
  
  def test_protect_page
    page = WikiPage.find_by_wiki_id_and_title(1, 'Another_page')
    assert !page.protected?
    @request.session[:user_id] = 2
    post :protect, :id => 1, :page => page.title, :protected => '1'
    assert_redirected_to :action => 'index', :id => 'ecookbook', :page => 'Another_page'
    assert page.reload.protected?
  end
  
  def test_unprotect_page
    page = WikiPage.find_by_wiki_id_and_title(1, 'CookBook_documentation')
    assert page.protected?
    @request.session[:user_id] = 2
    post :protect, :id => 1, :page => page.title, :protected => '0'
    assert_redirected_to :action => 'index', :id => 'ecookbook', :page => 'CookBook_documentation'
    assert !page.reload.protected?
  end
  
  def test_show_page_with_edit_link
    @request.session[:user_id] = 2
    get :index, :id => 1
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'a', :attributes => { :href => '/projects/1/wiki/CookBook_documentation/edit' }
  end
  
  def test_show_page_without_edit_link
    @request.session[:user_id] = 4
    get :index, :id => 1
    assert_response :success
    assert_template 'show'
    assert_no_tag :tag => 'a', :attributes => { :href => '/projects/1/wiki/CookBook_documentation/edit' }
  end  
  
  def test_edit_unprotected_page
    # Non members can edit unprotected wiki pages
    @request.session[:user_id] = 4
    get :edit, :id => 1, :page => 'Another_page'
    assert_response :success
    assert_template 'edit'
  end
  
  def test_edit_protected_page_by_nonmember
    # Non members can't edit protected wiki pages
    @request.session[:user_id] = 4
    get :edit, :id => 1, :page => 'CookBook_documentation'
    assert_response 403
  end
  
  def test_edit_protected_page_by_member
    @request.session[:user_id] = 2
    get :edit, :id => 1, :page => 'CookBook_documentation'
    assert_response :success
    assert_template 'edit'    
  end
  
  def test_history_of_non_existing_page_should_return_404
    get :history, :id => 1, :page => 'Unknown_page'
    assert_response 404
  end
end
