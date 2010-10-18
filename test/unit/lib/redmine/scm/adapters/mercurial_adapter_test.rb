
require File.dirname(__FILE__) + '/../../../../../test_helper'
begin
  require 'mocha'
  
  class MercurialAdapterClassTest < ActiveSupport::TestCase
    
    TEMPLATES_DIR = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATES_DIR
    TEMPLATE_NAME = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_NAME
    TEMPLATE_EXTENSION = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_EXTENSION
    
    def setup
      @adapter_class = Redmine::Scm::Adapters::MercurialAdapter
    end
    
    def test_hgversion
      to_test = {
                    "0.9.5"                 => [0,9,5],
                    "1.0"                   => [1,0],
                    "1e4ddc9ac9f7+20080325" => [],
                    "1.0.1+20080525"        => [1,0,1],
                    "1916e629a29d"          => [] ,
                    "1.6"                   => [1,6],
                    "1.6.1"                 => [1,6,1],
                    "Mercurial Distributed SCM (version 1.6.3)" => [1,6,3],
                    ## Italian
                    # $ make local
                    # $ LANG=it ./hg --version
                    "Mercurial SCM Distribuito (versione 1.6.3+61-1c9bb7e00f71)" => [1,6,3],
                  }
      
      to_test.each do |s, v|
        test_hgversion_for(s, v)
      end
    end
    
    def test_template_path
      to_test = {
                    [0,9,5] => "0.9.5",
                    [1,0]   => "1.0"  ,
                    []      => "1.0"  ,
                    [1,0,1] => "1.0"  ,
                    [1,6]   => "1.0"  ,
                    [1,6,1] => "1.0"  ,
                  }
      
      to_test.each do |v, template|
        test_template_path_for(v, template)
      end
    end

    private

    def test_hgversion_for(hgversion, version)
      @adapter_class.expects(:hgversion_from_command_line).returns(hgversion)
      assert_equal version, @adapter_class.hgversion
    end

    def test_template_path_for(version, template)
      assert_equal "#{TEMPLATES_DIR}/#{TEMPLATE_NAME}-#{template}.#{TEMPLATE_EXTENSION}",
                   @adapter_class.template_path_for(version)
      assert File.exist?(@adapter_class.template_path_for(version))
    end
  end
  
rescue LoadError
  def test_fake; assert(false, "Requires mocha to run those tests")  end
end

class MercurialAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/mercurial_repository'

  if File.directory?(REPOSITORY_PATH)  
    def setup
      @adapter = Redmine::Scm::Adapters::MercurialAdapter.new(REPOSITORY_PATH)
    end

    def test_cat
      assert     @adapter.cat("sources/welcome_controller.rb", 2)
      assert_nil @adapter.cat("sources/welcome_controller.rb")
    end

    def test_access_by_nodeid
      path = 'sources/welcome_controller.rb'
      assert_equal @adapter.cat(path, 2),
                   @adapter.cat(path, '400bb8672109')
    end

    def test_access_by_fuzzy_nodeid
      path = 'sources/welcome_controller.rb'
      # falls back to nodeid
      assert_equal @adapter.cat(path, 2), @adapter.cat(path, '400')
    end

  else
    puts "Mercurial test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
