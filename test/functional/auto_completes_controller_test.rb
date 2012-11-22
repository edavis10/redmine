require File.expand_path('../../test_helper', __FILE__)

class AutoCompletesControllerTest < ActionController::TestCase
  fixtures :projects, :issues, :issue_statuses,
           :enumerations, :users, :issue_categories,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :journals, :journal_details

  def test_issues_should_not_be_case_sensitive
    get :issues, :project_id => 'ecookbook', :q => 'ReCiPe'
    assert_response :success
    assert_not_nil assigns(:issues)
    assert assigns(:issues).detect {|issue| issue.subject.match /recipe/}
  end

  def test_issues_should_accept_term_param
    get :issues, :project_id => 'ecookbook', :term => 'ReCiPe'
    assert_response :success
    assert_not_nil assigns(:issues)
    assert assigns(:issues).detect {|issue| issue.subject.match /recipe/}
  end

  def test_issues_should_return_issue_with_given_id
    get :issues, :project_id => 'subproject1', :q => '13'
    assert_response :success
    assert_not_nil assigns(:issues)
    assert assigns(:issues).include?(Issue.find(13))
  end

  def test_auto_complete_with_scope_all_should_search_other_projects
    get :issues, :project_id => 'ecookbook', :q => '13', :scope => 'all'
    assert_response :success
    assert_not_nil assigns(:issues)
    assert assigns(:issues).include?(Issue.find(13))
  end

  def test_auto_complete_without_project_should_search_all_projects
    get :issues, :q => '13'
    assert_response :success
    assert_not_nil assigns(:issues)
    assert assigns(:issues).include?(Issue.find(13))
  end

  def test_auto_complete_without_scope_all_should_not_search_other_projects
    get :issues, :project_id => 'ecookbook', :q => '13'
    assert_response :success
    assert_equal [], assigns(:issues)
  end

  def test_issues_should_return_json
    get :issues, :project_id => 'subproject1', :q => '13'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    issue = json.first
    assert_kind_of Hash, issue
    assert_equal 13, issue['id']
    assert_equal 13, issue['value']
    assert_equal 'Bug #13: Subproject issue two', issue['label']
  end
end
