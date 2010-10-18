require File.dirname(__FILE__) + '/../../../../../test_helper'

class BazaarAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/bazaar_repository'

  if File.directory?(REPOSITORY_PATH)
    def setup
      @adapter = Redmine::Scm::Adapters::BazaarAdapter.new(REPOSITORY_PATH)
    end

    def test_info
      info = @adapter.info
      assert_equal "7", info.lastrev.display_name
    end

    def test_entries
      current_entries = @adapter.entries
      assert_equal 2, current_entries.length
      assert_equal "root_level.txt", current_entries[1].name

      old_entries = @adapter.entries("", "johndoe@no.server-20100927142810-5hx3443dk9mdbs3t")
      assert_equal 2, old_entries.length
      assert_equal "mainfile.txt", old_entries[1].name

      entries_dir = @adapter.entries("directory")
      assert_equal 4, entries_dir.length
      assert_equal "config.txt", entries_dir[0].name
    end

    # NOT DONE YET!!!

  else
    puts "Bazaar test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
