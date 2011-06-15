# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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
require 'repositories_controller'

# Re-raise errors caught by the controller.
class RepositoriesController; def rescue_action(e) raise e end; end

class RepositoriesGitControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  PRJ_ID     = 3
  CHAR_1_HEX = "\xc3\x9c"

  ## Git, Mercurial and CVS path encodings are binary.
  ## Subversion supports URL encoding for path.
  ## Redmine Mercurial adapter and extension use URL encoding.
  ## Git accepts only binary path in command line parameter.
  ## So, there is no way to use binary command line parameter in JRuby.
  JRUBY_SKIP     = (RUBY_PLATFORM == 'java')
  JRUBY_SKIP_STR = "TODO: This test fails in JRuby"

  def setup
    @ruby19_non_utf8_pass =
      (RUBY_VERSION >= '1.9' && Encoding.default_external.to_s != 'UTF-8')

    @controller = RepositoriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    @repository = Repository::Git.create(
                      :project => Project.find(3),
                      :url     => REPOSITORY_PATH,
                      :path_encoding => 'ISO-8859-1'
                      )
    assert @repository
    @char_1        = CHAR_1_HEX.dup
    if @char_1.respond_to?(:force_encoding)
      @char_1.force_encoding('UTF-8')
    end

    Setting.default_language = 'en'
  end

  if File.directory?(REPOSITORY_PATH)
    def test_browse_root
      @repository.fetch_changesets
      @repository.reload
      get :show, :id => PRJ_ID
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 9, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'this_is_a_really_long_and_verbose_directory_name' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'copied_README' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'new_file.txt' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'renamed_test.txt' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'filemane with spaces.txt' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == ' filename with a leading space.txt ' && e.kind == 'file'}
      assert_not_nil assigns(:changesets)
      assigns(:changesets).size > 0
    end

    def test_browse_branch
      @repository.fetch_changesets
      @repository.reload
      get :show, :id => PRJ_ID, :rev => 'test_branch'
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 4, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'test.txt' && e.kind == 'file'}
      assert_not_nil assigns(:changesets)
      assigns(:changesets).size > 0
    end

    def test_browse_tag
      @repository.fetch_changesets
      @repository.reload
       [
        "tag00.lightweight",
        "tag01.annotated",
       ].each do |t1|
        get :show, :id => PRJ_ID, :rev => t1
        assert_response :success
        assert_template 'show'
        assert_not_nil assigns(:entries)
        assigns(:entries).size > 0
        assert_not_nil assigns(:changesets)
        assigns(:changesets).size > 0
      end
    end

    def test_browse_directory
      @repository.fetch_changesets
      @repository.reload
      get :show, :id => PRJ_ID, :path => ['images']
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['edit.png'], assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'edit.png'}
      assert_not_nil entry
      assert_equal 'file', entry.kind
      assert_equal 'images/edit.png', entry.path
      assert_not_nil assigns(:changesets)
      assigns(:changesets).size > 0
    end

    def test_browse_at_given_revision
      @repository.fetch_changesets
      @repository.reload
      get :show, :id => PRJ_ID, :path => ['images'],
          :rev => '7234cb2750b63f47bff735edc50a1c0a433c2518'
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png'], assigns(:entries).collect(&:name)
      assert_not_nil assigns(:changesets)
      assigns(:changesets).size > 0
    end

    def test_changes
      get :changes, :id => PRJ_ID, :path => ['images', 'edit.png']
      assert_response :success
      assert_template 'changes'
      assert_tag :tag => 'h2', :content => 'edit.png'
    end

    def test_entry_show
      get :entry, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'entry'
      # Line 19
      assert_tag :tag => 'th',
                 :content => '11',
                 :attributes => { :class => 'line-num' },
                 :sibling => { :tag => 'td', :content => /WITHOUT ANY WARRANTY/ }
    end

    def test_entry_show_latin_1
      if @ruby19_non_utf8_pass
        puts_ruby19_non_utf8_pass()
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            get :entry, :id => PRJ_ID,
                :path => ['latin-1-dir', "test-#{@char_1}.txt"], :rev => r1
            assert_response :success
            assert_template 'entry'
            assert_tag :tag => 'th',
                   :content => '1',
                   :attributes => { :class => 'line-num' },
                   :sibling => { :tag => 'td',
                                 :content => /test-#{@char_1}.txt/ }
          end
        end
      end
    end

    def test_entry_download
      get :entry, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb'],
          :format => 'raw'
      assert_response :success
      # File content
      assert @response.body.include?('WITHOUT ANY WARRANTY')
    end

    def test_directory_entry
      get :entry, :id => PRJ_ID, :path => ['sources']
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'sources', assigns(:entry).name
    end

    def test_diff
      @repository.fetch_changesets
      @repository.reload
      # Full diff of changeset 2f9c0091
      ['inline', 'sbs'].each do |dt|
        get :diff,
            :id   => PRJ_ID,
            :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
            :type => dt
        assert_response :success
        assert_template 'diff'
        # Line 22 removed
        assert_tag :tag => 'th',
                   :content => /22/,
                   :sibling => { :tag => 'td',
                                 :attributes => { :class => /diff_out/ },
                                 :content => /def remove/ }
        assert_tag :tag => 'h2', :content => /2f9c0091/
      end
    end

    def test_diff_truncated
      @repository.fetch_changesets
      @repository.reload
      Setting.diff_max_lines_displayed = 5

      # Truncated diff of changeset 2f9c0091
      with_cache do
        get :diff, :id   => PRJ_ID, :type => 'inline',
            :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
        assert_response :success
        assert @response.body.include?("... This diff was truncated")

        Setting.default_language = 'fr'
        get :diff, :id   => PRJ_ID, :type => 'inline',
            :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
        assert_response :success
        assert ! @response.body.include?("... This diff was truncated")
        assert @response.body.include?("... Ce diff")
      end
    end

    def test_diff_two_revs
      @repository.fetch_changesets
      @repository.reload
      ['inline', 'sbs'].each do |dt|
        get :diff,
            :id     => PRJ_ID,
            :rev    => '61b685fbe55ab05b5ac68402d5720c1a6ac973d1',
            :rev_to => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
            :type   => dt
        assert_response :success
        assert_template 'diff'
        diff = assigns(:diff)
        assert_not_nil diff
        assert_tag :tag => 'h2', :content => /2f9c0091:61b685fb/
      end
    end

    def test_diff_latin_1
      if @ruby19_non_utf8_pass
        puts_ruby19_non_utf8_pass()
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            ['inline', 'sbs'].each do |dt|
              get :diff, :id => PRJ_ID, :rev => r1, :type => dt
              assert_response :success
              assert_template 'diff'
              assert_tag :tag => 'thead',
                         :descendant => {
                           :tag => 'th',
                           :attributes => { :class => 'filename' } ,
                           :content => /latin-1-dir\/test-#{@char_1}.txt/ ,
                          },
                         :sibling => {
                           :tag => 'tbody',
                           :descendant => {
                              :tag => 'td',
                              :attributes => { :class => /diff_in/ },
                              :content => /test-#{@char_1}.txt/
                           }
                         }
            end
          end
        end
      end
    end

    def test_annotate
      get :annotate, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'annotate'
      # Line 24, changeset 2f9c0091
      assert_tag :tag => 'th', :content => '24',
                 :sibling => {
                    :tag => 'td',
                    :child => {
                       :tag => 'a',
                       :content => /2f9c0091/
                       }
                    }
      assert_tag :tag => 'th', :content => '24',
                 :sibling => { :tag => 'td', :content => /jsmith/ }
      assert_tag :tag => 'th', :content => '24',
                 :sibling => {
                    :tag => 'td',
                    :child => {
                       :tag => 'a',
                       :content => /2f9c0091/
                       }
                    }
      assert_tag :tag => 'th', :content => '24',
                 :sibling => { :tag => 'td', :content => /watcher =/ }
    end

    def test_annotate_at_given_revision
      @repository.fetch_changesets
      @repository.reload
      get :annotate, :id => PRJ_ID, :rev => 'deff7',
          :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'annotate'
      assert_tag :tag => 'h2', :content => /@ deff712f/
    end

    def test_annotate_binary_file
      get :annotate, :id => PRJ_ID, :path => ['images', 'edit.png']
      assert_response 500
      assert_tag :tag => 'p', :attributes => { :id => /errorExplanation/ },
                              :content => /cannot be annotated/
    end

    def test_annotate_latin_1
      if @ruby19_non_utf8_pass
        puts_ruby19_non_utf8_pass()
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            get :annotate, :id => PRJ_ID,
                :path => ['latin-1-dir', "test-#{@char_1}.txt"], :rev => r1
            assert_tag :tag => 'th',
                       :content => '1',
                       :attributes => { :class => 'line-num' },
                       :sibling => { :tag => 'td',
                                     :content => /test-#{@char_1}.txt/ }
          end
        end
      end
    end

    def test_revision
      @repository.fetch_changesets
      @repository.reload
      ['61b685fbe55ab05b5ac68402d5720c1a6ac973d1', '61b685f'].each do |r|
        get :revision, :id => PRJ_ID, :rev => r
        assert_response :success
        assert_template 'revision'
      end
    end

    def test_empty_revision
      @repository.fetch_changesets
      @repository.reload
      ['', ' ', nil].each do |r|
        get :revision, :id => PRJ_ID, :rev => r
        assert_response 404
        assert_error_tag :content => /was not found/
      end
    end

    private

    def puts_ruby19_non_utf8_pass
      puts "TODO: This test fails in Ruby 1.9 " +
           "and Encoding.default_external is not UTF-8. " +
           "Current value is '#{Encoding.default_external.to_s}'"
    end
  else
    puts "Git test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end

  private
  def with_cache(&block)
    before = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
    block.call
    ActionController::Base.perform_caching = before
  end
end
