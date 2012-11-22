# Settings specified here will take precedence over those in config/application.rb
RedmineApp::Application.configure do
  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  #config.action_controller.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  config.action_mailer.perform_deliveries = true

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Skip protect_from_forgery in requests
  # http://m.onkey.org/2007/9/28/csrf-protection-for-your-existing-rails-application
  config.action_controller.allow_forgery_protection = false

  config.active_support.deprecation = :log

  config.secret_token = 'a secret token for running the tests'
end
