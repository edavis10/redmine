
require File.dirname(__FILE__) + '/../../../../../test_helper'
begin
  require 'mocha'
  
  class MercurialAdapterTest < ActiveSupport::TestCase
    
    TEMPLATES_DIR = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATES_DIR
    TEMPLATE_NAME = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_NAME
    TEMPLATE_EXTENSION = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_EXTENSION
    
    REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/mercurial_repository'

    def setup
      @adapter = Redmine::Scm::Adapters::MercurialAdapter
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
      @adapter.expects(:hgversion_from_command_line).returns(hgversion)
      assert_equal version, @adapter.hgversion
    end
    
    def test_template_path_for(version, template)
      assert_equal "#{TEMPLATES_DIR}/#{TEMPLATE_NAME}-#{template}.#{TEMPLATE_EXTENSION}",
                   @adapter.template_path_for(version)
      assert File.exist?(@adapter.template_path_for(version))
    end
  end
  
rescue LoadError
  class MercurialMochaFake < ActiveSupport::TestCase
    def test_fake; assert(false, "Requires mocha to run those tests")  end
  end
end

