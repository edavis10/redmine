# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class RepositoryBazaarTest < ActiveSupport::TestCase
  fixtures :projects

  include Redmine::I18n

  REPOSITORY_PATH = Rails.root.join('tmp/test/bazaar_repository/trunk').to_s
  REPOSITORY_PATH.gsub!(/\/+/, '/')
  NUM_REV = 4

  def setup
    @project = Project.find(3)
    @repository = Repository::Bazaar.create(
              :project => @project, :url => "file:///#{REPOSITORY_PATH}",
              :log_encoding => 'UTF-8')
    assert @repository
  end

  def test_blank_path_to_repository_error_message
    set_language_if_valid 'en'
    repo = Repository::Bazaar.new(
                          :project      => @project,
                          :identifier   => 'test',
                          :log_encoding => 'UTF-8'
                        )
    assert !repo.save
    assert_include "Path to repository can't be blank",
                   repo.errors.full_messages
  end

  def test_blank_path_to_repository_error_message_fr
    set_language_if_valid 'fr'
    str = "Chemin du d\xc3\xa9p\xc3\xb4t doit \xc3\xaatre renseign\xc3\xa9(e)"
    str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
    repo = Repository::Bazaar.new(
                          :project      => @project,
                          :url          => "",
                          :identifier   => 'test',
                          :log_encoding => 'UTF-8'
                        )
    assert !repo.save
    assert_include str, repo.errors.full_messages
  end

  if File.directory?(REPOSITORY_PATH)
    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal NUM_REV, @repository.changesets.count
      assert_equal 9, @repository.filechanges.count
      assert_equal 'Initial import', @repository.changesets.find_by_revision('1').comments
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # Remove changesets with revision > 5
      @repository.changesets.find(:all).each {|c| c.destroy if c.revision.to_i > 2}
      @project.reload
      assert_equal 2, @repository.changesets.count

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
    end

    def test_entries
      entries = @repository.entries
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
      assert_equal 2, entries.size

      assert_equal 'dir', entries[0].kind
      assert_equal 'directory', entries[0].name

      assert_equal 'file', entries[1].kind
      assert_equal 'doc-mkdir.txt', entries[1].name
    end

    def test_entries_in_subdirectory
      entries = @repository.entries('directory')
      assert_equal 3, entries.size

      assert_equal 'file', entries.last.kind
      assert_equal 'edit.png', entries.last.name
    end

    def test_previous
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('3')
      assert_equal @repository.find_changeset_by_name('2'), changeset.previous
    end

    def test_previous_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('1')
      assert_nil changeset.previous
    end

    def test_next
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('2')
      assert_equal @repository.find_changeset_by_name('3'), changeset.next
    end

    def test_next_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('4')
      assert_nil changeset.next
    end
  else
    puts "Bazaar test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
