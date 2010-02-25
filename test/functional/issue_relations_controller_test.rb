require File.dirname(__FILE__) + '/../test_helper'
require 'issue_relations_controller'

# Re-raise errors caught by the controller.
class IssueRelationsController; def rescue_action(e) raise e end; end


class IssueRelationsControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :issue_relations,
           :enabled_modules,
           :enumerations,
           :trackers
  
  def setup
    @controller = IssueRelationsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end
  
  def test_new_routing
    assert_routing(
      {:method => :post, :path => '/issues/1/relations'},
      {:controller => 'issue_relations', :action => 'new', :issue_id => '1'}
    )
  end
  
  def test_new
    assert_difference 'IssueRelation.count' do
      @request.session[:user_id] = 3
      post :new, :issue_id => 1, 
                 :relation => {:issue_to_id => '2', :relation_type => 'relates', :delay => ''}
    end
  end
  
  def test_new_should_accept_id_with_hash
    assert_difference 'IssueRelation.count' do
      @request.session[:user_id] = 3
      post :new, :issue_id => 1, 
                 :relation => {:issue_to_id => '#2', :relation_type => 'relates', :delay => ''}
    end
  end
  
  def test_new_should_not_break_with_non_numerical_id
    assert_no_difference 'IssueRelation.count' do
      assert_nothing_raised do
        @request.session[:user_id] = 3
        post :new, :issue_id => 1, 
                   :relation => {:issue_to_id => 'foo', :relation_type => 'relates', :delay => ''}
      end
    end
  end
  
  def test_should_create_relations_with_visible_issues_only
    Setting.cross_project_issue_relations = '1'
    assert_nil Issue.visible(User.find(3)).find_by_id(4)
    
    assert_no_difference 'IssueRelation.count' do
      @request.session[:user_id] = 3
      post :new, :issue_id => 1, 
                 :relation => {:issue_to_id => '4', :relation_type => 'relates', :delay => ''}
    end
  end
  
  def test_destroy_routing
    assert_recognizes( #TODO: use DELETE on issue URI
      {:controller => 'issue_relations', :action => 'destroy', :issue_id => '1', :id => '23'},
      {:method => :post, :path => '/issues/1/relations/23/destroy'}
    )
  end
  
  def test_destroy
    assert_difference 'IssueRelation.count', -1 do
      @request.session[:user_id] = 3
      post :destroy, :id => '2', :issue_id => '3'
    end
  end
end
