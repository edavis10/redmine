require File.expand_path('../../../../../../test_helper', __FILE__)
begin
  require 'mocha'
  
  class MercurialAdapterTest < ActiveSupport::TestCase
    
    TEMPLATES_DIR = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATES_DIR
    TEMPLATE_NAME = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_NAME
    TEMPLATE_EXTENSION = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_EXTENSION
    
    REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/mercurial_repository'

    if File.directory?(REPOSITORY_PATH)  
      def setup
        @adapter = Redmine::Scm::Adapters::MercurialAdapter.new(REPOSITORY_PATH)
      end

      def test_hgversion
        to_test = { "Mercurial Distributed SCM (version 0.9.5)\n"  => [0,9,5],
                    "Mercurial Distributed SCM (1.0)\n"            => [1,0],
                    "Mercurial Distributed SCM (1e4ddc9ac9f7+20080325)\n" => nil,
                    "Mercurial Distributed SCM (1.0.1+20080525)\n" => [1,0,1],
                    "Mercurial Distributed SCM (1916e629a29d)\n"   => nil,
                    "Mercurial SCM Distribuito (versione 0.9.5)\n" => [0,9,5],
                    "(1.6)\n(1.7)\n(1.8)"           => [1,6],
                    "(1.7.1)\r\n(1.8.1)\r\n(1.9.1)" => [1,7,1]}

        to_test.each do |s, v|
          test_hgversion_for(s, v)
        end
      end

      def test_template_path
        to_test = { [0,9,5] => "0.9.5",
                       [1,0]    => "1.0",
                       []       => "1.0",
                       [1,0,1]  => "1.0",
                       [1,7]    => "1.0",
                       [1,7,1]  => "1.0"}
        to_test.each do |v, template|
          test_template_path_for(v, template)
        end
      end

      def test_cat
        assert     @adapter.cat("sources/welcome_controller.rb", 2)
        assert_nil @adapter.cat("sources/welcome_controller.rb")
      end

      private

      def test_hgversion_for(hgversion, version)
        @adapter.class.expects(:hgversion_from_command_line).returns(hgversion)
        assert_equal version, @adapter.class.hgversion
      end

      def test_template_path_for(version, template)
        assert_equal "#{TEMPLATES_DIR}/#{TEMPLATE_NAME}-#{template}.#{TEMPLATE_EXTENSION}",
                     @adapter.class.template_path_for(version)
        assert File.exist?(@adapter.class.template_path_for(version))
      end
    else
      puts "Mercurial test repository NOT FOUND. Skipping unit tests !!!"
      def test_fake; assert true end
    end
  end

rescue LoadError
  class MercurialMochaFake < ActiveSupport::TestCase
    def test_fake; assert(false, "Requires mocha to run those tests")  end
  end
end

