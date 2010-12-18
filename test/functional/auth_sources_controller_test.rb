require File.expand_path('../../test_helper', __FILE__)

class AuthSourcesControllerTest < ActionController::TestCase
  fixtures :all

  def setup
    @request.session[:user_id] = 1
  end

  context "get :index" do
    setup do
      get :index
    end

    should_assign_to :auth_sources
    should_assign_to :auth_source_pages
    should_respond_with :success
    should_render_template :index
  end

  context "get :new" do
    setup do
      get :new
    end

    should_assign_to :auth_source
    should_respond_with :success
    should_render_template :new

    should "initilize a new AuthSource" do
      assert_equal AuthSource, assigns(:auth_source).class
      assert assigns(:auth_source).new_record?
    end
  end

  context "post :create" do
    setup do
      post :create, :auth_source => {:name => 'Test'}
    end

    should_respond_with :redirect
    should_redirect_to("index") {{:action => 'index'}}
    should_set_the_flash_to /success/i
  end

  context "get :edit" do
    setup do
      @auth_source = AuthSource.generate!(:name => 'TestEdit')
      get :edit, :id => @auth_source.id
    end

    should_assign_to(:auth_source) {@auth_source}
    should_respond_with :success
    should_render_template :edit
  end

  context "post :update" do
    setup do
      @auth_source = AuthSource.generate!(:name => 'TestEdit')
      post :update, :id => @auth_source.id, :auth_source => {:name => 'TestUpdate'}
    end

    should_respond_with :redirect
    should_redirect_to("index") {{:action => 'index'}}
    should_set_the_flash_to /update/i
  end

  context "post :destroy" do
    context "without users" do
      setup do
        @auth_source = AuthSource.generate!(:name => 'TestEdit')
        post :destroy, :id => @auth_source.id
      end

      should_respond_with :redirect
      should_redirect_to("index") {{:action => 'index'}}
      should_set_the_flash_to /deletion/i

    end
    
    should "be tested with users"
  end
end
