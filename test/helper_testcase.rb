# Re-raise errors caught by the controller.
class StubController < ApplicationController
  def rescue_action(e) raise e end;
  attr_accessor :request, :url
end

class HelperTestCase < ActiveSupport::TestCase

  # Add other helpers here if you need them
  include ActionView::Helpers::ActiveRecordHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::PrototypeHelper

  def setup
    super

    @request    = ActionController::TestRequest.new
    @controller = StubController.new
    @controller.request = @request

    # Fake url rewriter so we can test url_for
    @controller.url = ActionController::UrlRewriter.new @request, {}
    
    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end

  def test_dummy
    # do nothing - required by test/unit
  end
end
