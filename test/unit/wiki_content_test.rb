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

class WikiContentTest < ActiveSupport::TestCase
  fixtures :projects, :enabled_modules,
           :users, :members, :member_roles, :roles,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @wiki = Wiki.find(1)
    @page = @wiki.pages.first
  end

  def test_create
    page = WikiPage.new(:wiki => @wiki, :title => "Page")
    page.content = WikiContent.new(:text => "Content text", :author => User.find(1), :comments => "My comment")
    assert page.save
    page.reload

    content = page.content
    assert_kind_of WikiContent, content
    assert_equal 1, content.version
    assert_equal 1, content.versions.length
    assert_equal "Content text", content.text
    assert_equal "My comment", content.comments
    assert_equal User.find(1), content.author
    assert_equal content.text, content.versions.last.text
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    page = WikiPage.new(:wiki => @wiki, :title => "A new page")
    page.content = WikiContent.new(:text => "Content text", :author => User.find(1), :comments => "My comment")

    with_settings :notified_events => %w(wiki_content_added) do
      assert page.save
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_update_should_be_versioned
    content = @page.content
    version_count = content.version
    content.text = "My new content"
    assert_difference 'WikiContent::Version.count' do
      assert content.save
    end
    content.reload
    assert_equal version_count+1, content.version
    assert_equal version_count+1, content.versions.length

    version = WikiContent::Version.first(:order => 'id DESC')
    assert_equal @page.id, version.page_id
    assert_equal '', version.compression
    assert_equal "My new content", version.data
    assert_equal "My new content", version.text
  end

  def test_update_with_gzipped_history
    with_settings :wiki_compression => 'gzip' do
      content = @page.content
      content.text = "My new content"
      assert_difference 'WikiContent::Version.count' do
        assert content.save
      end
    end

    version = WikiContent::Version.first(:order => 'id DESC')
    assert_equal @page.id, version.page_id
    assert_equal 'gzip', version.compression
    assert_not_equal "My new content", version.data
    assert_equal "My new content", version.text
  end

  def test_update_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    content = @page.content
    content.text = "My new content"

    with_settings :notified_events => %w(wiki_content_updated) do
      assert content.save
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_fetch_history
    assert !@page.content.versions.empty?
    @page.content.versions.each do |version|
      assert_kind_of String, version.text
    end
  end

  def test_large_text_should_not_be_truncated_to_64k
    page = WikiPage.new(:wiki => @wiki, :title => "Big page")
    page.content = WikiContent.new(:text => "a" * 500.kilobyte, :author => User.find(1))
    assert page.save
    page.reload
    assert_equal 500.kilobyte, page.content.text.size
  end
  
  def test_current_version
    content = WikiContent.find(11)
    assert_equal true, content.current_version?
    assert_equal true, content.versions.first(:order => 'version DESC').current_version?
    assert_equal false, content.versions.first(:order => 'version ASC').current_version?
  end
end
