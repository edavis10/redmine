desc "Run the Continous Integration tests for Redmine"
task :ci do
  # RAILS_ENV and ENV[] can diverge so force them both to test
  ENV['RAILS_ENV'] = 'test'
  RAILS_ENV = 'test'
  Rake::Task["ci:setup"].invoke
  Rake::Task["ci:build"].invoke
  Rake::Task["ci:teardown"].invoke
end

# Tasks can be hooked into by redefining them in a plugin
namespace :ci do
  desc "Setup Redmine for a new build."
  task :setup do
    Rake::Task["ci:dump_environment"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:schema:dump"].invoke
  end

  desc "Build Redmine"
  task :build do
    Rake::Task["test"].invoke
  end

  # Use this to cleanup after building or run post-build analysis.
  desc "Finish the build"
  task :teardown do
  end

  desc "Dump the environment information to a BUILD_ENVIRONMENT ENV variable for debugging"
  task :dump_environment do

    ENV['BUILD_ENVIRONMENT'] = ['ruby -v', 'gem -v', 'gem list'].collect do |command|
      result = `#{command}`
      "$ #{command}\n#{result}"
    end.join("\n")
    
  end
end

