require File.expand_path('../../test_helper', __FILE__)

class ActivitiesControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :groups_users,
           :enabled_modules,
           :workflows,
           :journals, :journal_details


  def test_project_index
    get :index, :id => 1, :with_subprojects => 0
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_tag :tag => "h3",
               :content => /#{2.days.ago.to_date.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue-edit/ },
                   :child => { :tag => "a",
                     :content => /(#{IssueStatus.find(2).name})/,
                   }
                 }
               }
  end

  def test_project_index_with_invalid_project_id_should_respond_404
    get :index, :id => 299
    assert_response 404
  end

  def test_previous_project_index
    get :index, :id => 1, :from => 3.days.ago.to_date
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_tag :tag => "h3",
               :content => /#{3.day.ago.to_date.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue/ },
                   :child => { :tag => "a",
                     :content => /Can&#x27;t print recipes/,
                   }
                 }
               }
  end

  def test_global_index
    @request.session[:user_id] = 1
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    i5 = Issue.find(5)
    d5 = User.find(1).time_to_date(i5.created_on)
    assert_tag :tag => "h3",
               :content => /#{d5.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue/ },
                   :child => { :tag => "a",
                     :content => /Subproject issue/,
                   }
                 }
               }
  end

  def test_user_index
    @request.session[:user_id] = 1
    get :index, :user_id => 2
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_select 'h2 a[href=/users/2]', :text => 'John Smith'

    i1 = Issue.find(1)
    d1 = User.find(1).time_to_date(i1.created_on)

    assert_tag :tag => "h3",
               :content => /#{d1.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue/ },
                   :child => { :tag => "a",
                     :content => /Can&#x27;t print recipes/,
                   }
                 }
               }
  end

  def test_user_index_with_invalid_user_id_should_respond_404
    get :index, :user_id => 299
    assert_response 404
  end

  def test_index_atom_feed
    get :index, :format => 'atom', :with_subprojects => 0
    assert_response :success
    assert_template 'common/feed'

    assert_tag :tag => 'link', :parent =>  {:tag => 'feed', :parent => nil },
        :attributes => {:rel => 'self', :href => 'http://test.host/activity.atom?with_subprojects=0'}
    assert_tag :tag => 'link', :parent =>  {:tag => 'feed', :parent => nil },
        :attributes => {:rel => 'alternate', :href => 'http://test.host/activity?with_subprojects=0'}

    assert_tag :tag => 'entry', :child => {
      :tag => 'link',
      :attributes => {:href => 'http://test.host/issues/11'}}
  end

  def test_index_atom_feed_with_explicit_selection
    get :index, :format => 'atom', :with_subprojects => 0,
      :show_changesets => 1,
      :show_documents => 1,
      :show_files => 1,
      :show_issues => 1,
      :show_messages => 1,
      :show_news => 1,
      :show_time_entries => 1,
      :show_wiki_edits => 1

    assert_response :success
    assert_template 'common/feed'

    assert_tag :tag => 'link', :parent =>  {:tag => 'feed', :parent => nil },
        :attributes => {:rel => 'self', :href => 'http://test.host/activity.atom?show_changesets=1&amp;show_documents=1&amp;show_files=1&amp;show_issues=1&amp;show_messages=1&amp;show_news=1&amp;show_time_entries=1&amp;show_wiki_edits=1&amp;with_subprojects=0'}
    assert_tag :tag => 'link', :parent => {:tag => 'feed', :parent => nil },
        :attributes => {:rel => 'alternate', :href => 'http://test.host/activity?show_changesets=1&amp;show_documents=1&amp;show_files=1&amp;show_issues=1&amp;show_messages=1&amp;show_news=1&amp;show_time_entries=1&amp;show_wiki_edits=1&amp;with_subprojects=0'}

    assert_tag :tag => 'entry', :child => {
      :tag => 'link',
      :attributes => {:href => 'http://test.host/issues/11'}}
  end

  def test_index_atom_feed_with_one_item_type
    get :index, :format => 'atom', :show_issues => '1'
    assert_response :success
    assert_template 'common/feed'
    assert_tag :tag => 'title', :content => /Issues/
  end
end
