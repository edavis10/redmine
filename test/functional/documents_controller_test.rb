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

require File.expand_path('../../test_helper', __FILE__)
require 'documents_controller'

# Re-raise errors caught by the controller.
class DocumentsController; def rescue_action(e) raise e end; end

class DocumentsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules, :documents, :enumerations
  
  def setup
    @controller = DocumentsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end
  
  def test_index
    # Sets a default category
    e = Enumeration.find_by_name('Technical documentation')
    e.update_attributes(:is_default => true)
    
    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:grouped)
    
    # Default category selected in the new document form
    assert_tag :select, :attributes => {:name => 'document[category_id]'},
                        :child => {:tag => 'option', :attributes => {:selected => 'selected'},
                                                     :content => 'Technical documentation'}
  end
  
  def test_index_with_long_description
    # adds a long description to the first document
    doc = documents(:documents_001)
    doc.update_attributes(:description => <<LOREM)
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut egestas, mi vehicula varius varius, ipsum massa fermentum orci, eget tristique ante sem vel mi. Nulla facilisi. Donec enim libero, luctus ac sagittis sit amet, vehicula sagittis magna. Duis ultrices molestie ante, eget scelerisque sem iaculis vitae. Etiam fermentum mauris vitae metus pharetra condimentum fermentum est pretium. Proin sollicitudin elementum quam quis pharetra.  Aenean facilisis nunc quis elit volutpat mollis. Aenean eleifend varius euismod. Ut dolor est, congue eget dapibus eget, elementum eu odio. Integer et lectus neque, nec scelerisque nisi. EndOfLineHere

Vestibulum non velit mi. Aliquam scelerisque libero ut nulla fringilla a sollicitudin magna rhoncus.  Praesent a nunc lorem, ac porttitor eros. Sed ac diam nec neque interdum adipiscing quis quis justo. Donec arcu nunc, fringilla eu dictum at, venenatis ac sem. Vestibulum quis elit urna, ac mattis sapien. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
LOREM
    
    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'

    # should only truncate on new lines to avoid breaking wiki formatting
    assert_select '.wiki p', :text => (doc.description.split("\n").first + '...')
    assert_select '.wiki p', :text => Regexp.new(Regexp.escape("EndOfLineHere..."))
  end
  
  def test_new_with_one_attachment
    ActionMailer::Base.deliveries.clear
    Setting.notified_events << 'document_added'
    @request.session[:user_id] = 2
    set_tmp_attachments_directory
    
    post :new, :project_id => 'ecookbook',
               :document => { :title => 'DocumentsControllerTest#test_post_new',
                              :description => 'This is a new document',
                              :category_id => 2},
               :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
               
    assert_redirected_to '/projects/ecookbook/documents'
    
    document = Document.find_by_title('DocumentsControllerTest#test_post_new')
    assert_not_nil document
    assert_equal Enumeration.find(2), document.category
    assert_equal 1, document.attachments.size
    assert_equal 'testfile.txt', document.attachments.first.filename
    assert_equal 1, ActionMailer::Base.deliveries.size
  end
  
  def test_destroy
    @request.session[:user_id] = 2
    post :destroy, :id => 1
    assert_redirected_to '/projects/ecookbook/documents'
    assert_nil Document.find_by_id(1)
  end
end
