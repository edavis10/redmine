# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)
require 'pp'
class RepositoryCvsTest < ActiveSupport::TestCase
  fixtures :projects

  # No '..' in the repository path
  REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/cvs_repository'
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  # CVS module
  MODULE_NAME    = 'test'
  CHANGESETS_NUM = 7

  def setup
    @project = Project.find(3)
    @repository = Repository::Cvs.create(:project => @project, 
                                         :root_url => REPOSITORY_PATH,
                                         :url => MODULE_NAME,
                                         :log_encoding => 'UTF-8')
    assert @repository
  end

  if File.directory?(REPOSITORY_PATH)  
    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @repository.reload

      assert_equal CHANGESETS_NUM, @repository.changesets.count
      assert_equal 16, @repository.changes.count
      assert_not_nil @repository.changesets.find_by_comments('Two files changed')

      r2 = @repository.changesets.find_by_revision('2')
      assert_equal 'v1-20071213-162510', r2.scmid
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      # Remove changesets with revision > 3
      @repository.changesets.find(:all).each {|c| c.destroy if c.revision.to_i > 3}
      @repository.reload
      assert_equal 3, @repository.changesets.count
      assert_equal %w|3 2 1|, @repository.changesets.collect(&:revision)

      rev3_commit = @repository.changesets.find(:first, :order => 'committed_on DESC')
      assert_equal '3', rev3_commit.revision
       # 2007-12-14 01:27:22 +0900
      rev3_committed_on = Time.gm(2007, 12, 13, 16, 27, 22)
      assert_equal 'HEAD-20071213-162722', rev3_commit.scmid
      assert_equal rev3_committed_on, rev3_commit.committed_on
      latest_rev = @repository.latest_changeset
      assert_equal rev3_committed_on, latest_rev.committed_on

      @repository.fetch_changesets
      @repository.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count

      assert_equal %w|7 6 5 4 3 2 1|, @repository.changesets.collect(&:revision)
      rev5_commit = @repository.changesets.find_by_revision('5')
      assert_equal 'HEAD-20071213-163001', rev5_commit.scmid
       # 2007-12-14 01:30:01 +0900
      rev5_committed_on = Time.gm(2007, 12, 13, 16, 30, 1)
      assert_equal rev5_committed_on, rev5_commit.committed_on
    end

    def test_deleted_files_should_not_be_listed
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @repository.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count

      entries = @repository.entries('sources')
      assert entries.detect {|e| e.name == 'watchers_controller.rb'}
      assert_nil entries.detect {|e| e.name == 'welcome_controller.rb'}
    end

    def test_entries_rev3
      @repository.fetch_changesets
      @repository.reload
      entries = @repository.entries('', '3')
      assert_equal 3, entries.size
      assert_equal entries[2].name, "README"
      assert_equal entries[2].lastrev.time, Time.gm(2007, 12, 13, 16, 27, 22)
      assert_equal entries[2].lastrev.identifier, '3'
      assert_equal entries[2].lastrev.revision, '3'
      assert_equal entries[2].lastrev.author, 'LANG'
    end

    def test_entries_invalid_path
      @repository.fetch_changesets
      @repository.reload
      assert_nil @repository.entries('missing')
      assert_nil @repository.entries('missing', '3')
    end

    def test_entries_invalid_revision
      @repository.fetch_changesets
      @repository.reload
      assert_nil @repository.entries('', '123')
    end

    def test_cat
      @repository.fetch_changesets
      @repository.reload
      buf = @repository.cat('README')
      assert buf
      lines = buf.split("\n")
      assert_equal 3, lines.length
      buf = lines[1].gsub(/\r$/, "")
      assert_equal 'with one change', buf
      buf = @repository.cat('README', '1')
      assert buf
      lines = buf.split("\n")
      assert_equal 1, lines.length
      buf = lines[0].gsub(/\r$/, "")
      assert_equal 'CVS test repository', buf
      assert_nil @repository.cat('missing.rb')

      # sources/welcome_controller.rb is removed at revision 5.
      assert @repository.cat('sources/welcome_controller.rb', '4')
      assert @repository.cat('sources/welcome_controller.rb', '5').blank?

      # invalid revision
      assert @repository.cat('README', '123').blank?
    end

    def test_annotate
      @repository.fetch_changesets
      @repository.reload
      ann = @repository.annotate('README')
      assert ann
      assert_equal 3, ann.revisions.length
      assert_equal '1.2', ann.revisions[1].revision
      assert_equal 'LANG', ann.revisions[1].author
      assert_equal 'with one change', ann.lines[1]

      ann = @repository.annotate('README', '1')
      assert ann
      assert_equal 1, ann.revisions.length
      assert_equal '1.1', ann.revisions[0].revision
      assert_equal 'LANG', ann.revisions[0].author
      assert_equal 'CVS test repository', ann.lines[0]

     # invalid revision
     assert_nil @repository.annotate('README', '123')
   end

  else
    puts "CVS test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
