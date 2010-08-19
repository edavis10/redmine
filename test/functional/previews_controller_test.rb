require File.dirname(__FILE__) + '/../test_helper'

class PreviewsControllerTest < ActionController::TestCase
  fixtures :all

  def test_preview_new_issue
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :issue => {:description => 'Foo'}
    assert_response :success
    assert_template 'preview'
    assert_not_nil assigns(:description)
  end
                              
  def test_preview_issue_notes
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :id => 1, :issue => {:description => Issue.find(1).description}, :notes => 'Foo'
    assert_response :success
    assert_template 'preview'
    assert_not_nil assigns(:notes)
  end

end
