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

    def test_revisions_no_options
      revs = @adapter.revisions
      assert_equal 8, revs.length
      last_rev = revs[0]
      sub_rev = revs[1]
      assert_equal "7", last_rev.display_name
      assert_equal "second@no.server-20100927143627-e2mreqlpaodcixpg", last_rev.identifier
      assert_equal "Second Developer <second@no.server>", last_rev.author
      assert_equal Time.gm(2010,9,27,14,36,27).utc, last_rev.time.utc
      assert_equal "4.1.1", sub_rev.display_name
      assert_equal "johndoe@no.server-20100927143451-vw9ij1q1max8nakq", sub_rev.identifier
      assert_equal "John Doe <johndoe@no.server>", sub_rev.author
      assert_equal Time.gm(2010,9,27,14,34,51).utc, sub_rev.time.utc
      [last_rev, sub_rev].each do |r|
        assert_equal 1, r.paths.length
        assert_equal "/directory/config.txt", r.paths[0][:path]
        assert_equal "A", r.paths[0][:action]
        assert_equal "config.txt-20100927143445-xgkt26w4b98wdc15-1", r.paths[0][:revision]
      end
    end

    def test_revision_path
      revs = @adapter.revisions("directory/second_file.txt")
      assert_equal 2, revs.length
      assert_equal "6", revs[0].display_name
      assert_equal "5", revs[-1].display_name
      assert_equal 2, revs[0].paths.length
    end

    def test_revisions_identifers
      revs = @adapter.revisions(nil, "second@no.server-20100927143409-waety1q0cm1ur3sv", "johndoe@no.server-20100927142845-un2x20a6r2t3nz1w")
      assert_equal 3, revs.length
      assert_equal "6", revs[0].display_name
      assert_equal "4", revs[-1].display_name

      revs = @adapter.revisions(nil, "second@no.server-20100927143409-waety1q0cm1ur3sv")
      assert_equal 6, revs.length
      assert_equal "6", revs[0].display_name
      assert_equal "1", revs[-1].display_name

      revs = @adapter.revisions(nil, nil, "johndoe@no.server-20100927142845-un2x20a6r2t3nz1w")
      assert_equal 5, revs.length
      assert_equal "7", revs[0].display_name
      assert_equal "4", revs[-1].display_name
    end

    def test_revisions_options
      revs = @adapter.revisions(nil, nil, nil, {:since => Time.gm(2010,9,27,14,34,0).localtime})
      assert_equal 3, revs.length
      assert_equal "7", revs[0].display_name
      assert_equal "6", revs[-1].display_name
    end

    def test_diff
      diff = @adapter.diff(nil, "second@no.server-20100927143627-e2mreqlpaodcixpg")
      assert_equal 6, diff.length
      assert_equal "+This is a placeholder for configuration data\n", diff[4]

      diff = @adapter.diff(nil, "johndoe@no.server-20100927142810-5hx3443dk9mdbs3t", "johndoe@no.server-20100927142357-09lh9svlopfrt2zh")
      assert_equal 10, diff.length
      assert_equal "+This file is in the directory\n", diff[7]
    end

    def test_cat
      assert_equal "#First file, not much to say here\nThe above line is incorrect\n", @adapter.cat("root_level.txt")
      assert_equal "First file, not much to say here\n", @adapter.cat("root_level.txt", "johndoe@no.server-20100927142845-un2x20a6r2t3nz1w")
    end

    def test_annotate
      an = @adapter.annotate("directory/second_file.txt")
      assert_equal 2, an.lines.length
      assert_equal "second@no.server-20100927143241-aknlenpvde342upv", an.revisions[0].identifier
      assert_equal 'second@no.server', an.revisions[0].author      
      assert_equal "This file was created by second developer", an.lines[0]
      assert_equal "second@no.server-20100927143409-waety1q0cm1ur3sv", an.revisions[1].identifier
      assert_equal "More code from", an.lines[1]
    end

  else
    puts "Bazaar test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
