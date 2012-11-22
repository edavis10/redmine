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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::WikiFormatting::MacrosTest < ActionView::TestCase
  include ApplicationHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
  include ERB::Util
  extend ActionView::Helpers::SanitizeHelper::ClassMethods

  fixtures :projects, :roles, :enabled_modules, :users,
                      :repositories, :changesets,
                      :trackers, :issue_statuses, :issues,
                      :versions, :documents,
                      :wikis, :wiki_pages, :wiki_contents,
                      :boards, :messages,
                      :attachments

  def setup
    super
    @project = nil
  end

  def teardown
  end

  def test_macro_registration
    Redmine::WikiFormatting::Macros.register do
      macro :foo do |obj, args|
        "Foo: #{args.size} (#{args.join(',')}) (#{args.class.name})"
      end
    end

    assert_equal '<p>Foo: 0 () (Array)</p>', textilizable("{{foo}}")
    assert_equal '<p>Foo: 0 () (Array)</p>', textilizable("{{foo()}}")
    assert_equal '<p>Foo: 1 (arg1) (Array)</p>', textilizable("{{foo(arg1)}}")
    assert_equal '<p>Foo: 2 (arg1,arg2) (Array)</p>', textilizable("{{foo(arg1, arg2)}}")
  end

  def test_macro_registration_parse_args_set_to_false_should_disable_arguments_parsing
    Redmine::WikiFormatting::Macros.register do
      macro :bar, :parse_args => false do |obj, args|
        "Bar: (#{args}) (#{args.class.name})"
      end
    end

    assert_equal '<p>Bar: (args, more args) (String)</p>', textilizable("{{bar(args, more args)}}")
    assert_equal '<p>Bar: () (String)</p>', textilizable("{{bar}}")
    assert_equal '<p>Bar: () (String)</p>', textilizable("{{bar()}}")
  end

  def test_macro_registration_with_3_args_should_receive_text_argument
    Redmine::WikiFormatting::Macros.register do
      macro :baz do |obj, args, text|
        "Baz: (#{args.join(',')}) (#{text.class.name}) (#{text})"
      end
    end

    assert_equal "<p>Baz: () (NilClass) ()</p>", textilizable("{{baz}}")
    assert_equal "<p>Baz: () (NilClass) ()</p>", textilizable("{{baz()}}")
    assert_equal "<p>Baz: () (String) (line1\nline2)</p>", textilizable("{{baz()\nline1\nline2\n}}")
    assert_equal "<p>Baz: (arg1,arg2) (String) (line1\nline2)</p>", textilizable("{{baz(arg1, arg2)\nline1\nline2\n}}")
  end

  def test_multiple_macros_on_the_same_line
    Redmine::WikiFormatting::Macros.macro :foo do |obj, args|
      args.any? ? "args: #{args.join(',')}" : "no args" 
    end

    assert_equal '<p>no args no args</p>', textilizable("{{foo}} {{foo}}")
    assert_equal '<p>args: a,b no args</p>', textilizable("{{foo(a,b)}} {{foo}}")
    assert_equal '<p>args: a,b args: c,d</p>', textilizable("{{foo(a,b)}} {{foo(c,d)}}")
    assert_equal '<p>no args args: c,d</p>', textilizable("{{foo}} {{foo(c,d)}}")
  end

  def test_macro_should_receive_the_object_as_argument_when_with_object_and_attribute
    issue = Issue.find(1)
    issue.description = "{{hello_world}}"
    assert_equal '<p>Hello world! Object: Issue, Called with no argument and no block of text.</p>', textilizable(issue, :description)
  end

  def test_macro_should_receive_the_object_as_argument_when_called_with_object_option
    text = "{{hello_world}}"
    assert_equal '<p>Hello world! Object: Issue, Called with no argument and no block of text.</p>', textilizable(text, :object => Issue.find(1))
  end


  def test_macro_exception_should_be_displayed
    Redmine::WikiFormatting::Macros.macro :exception do |obj, args|
      raise "My message"
    end

    text = "{{exception}}"
    assert_include '<div class="flash error">Error executing the <strong>exception</strong> macro (My message)</div>', textilizable(text)
  end

  def test_macro_arguments_should_not_be_parsed_by_formatters
    text = '{{hello_world(http://www.redmine.org, #1)}}'
    assert_include 'Arguments: http://www.redmine.org, #1', textilizable(text)
  end

  def test_exclamation_mark_should_not_run_macros
    text = "!{{hello_world}}"
    assert_equal '<p>{{hello_world}}</p>', textilizable(text)
  end

  def test_exclamation_mark_should_escape_macros
    text = "!{{hello_world(<tag>)}}"
    assert_equal '<p>{{hello_world(&lt;tag&gt;)}}</p>', textilizable(text)
  end

  def test_unknown_macros_should_not_be_replaced
    text = "{{unknown}}"
    assert_equal '<p>{{unknown}}</p>', textilizable(text)
  end

  def test_unknown_macros_should_parsed_as_text
    text = "{{unknown(*test*)}}"
    assert_equal '<p>{{unknown(<strong>test</strong>)}}</p>', textilizable(text)
  end

  def test_unknown_macros_should_be_escaped
    text = "{{unknown(<tag>)}}"
    assert_equal '<p>{{unknown(&lt;tag&gt;)}}</p>', textilizable(text)
  end

  def test_html_safe_macro_output_should_not_be_escaped
    Redmine::WikiFormatting::Macros.macro :safe_macro do |obj, args|
      "<tag>".html_safe
    end
    assert_equal '<p><tag></p>', textilizable("{{safe_macro}}")
  end

  def test_macro_hello_world
    text = "{{hello_world}}"
    assert textilizable(text).match(/Hello world!/)
  end

  def test_macro_hello_world_should_escape_arguments
    text = "{{hello_world(<tag>)}}"
    assert_include 'Arguments: &lt;tag&gt;', textilizable(text)
  end

  def test_macro_macro_list
    text = "{{macro_list}}"
    assert_match %r{<code>hello_world</code>}, textilizable(text)
  end

  def test_macro_include
    @project = Project.find(1)
    # include a page of the current project wiki
    text = "{{include(Another page)}}"
    assert_include 'This is a link to a ticket', textilizable(text)

    @project = nil
    # include a page of a specific project wiki
    text = "{{include(ecookbook:Another page)}}"
    assert_include 'This is a link to a ticket', textilizable(text)

    text = "{{include(ecookbook:)}}"
    assert_include 'CookBook documentation', textilizable(text)

    text = "{{include(unknowidentifier:somepage)}}"
    assert_include 'Page not found', textilizable(text)
  end

  def test_macro_child_pages
    expected =  "<p><ul class=\"pages-hierarchy\">\n" +
                 "<li><a href=\"/projects/ecookbook/wiki/Child_1\">Child 1</a></li>\n" +
                 "<li><a href=\"/projects/ecookbook/wiki/Child_2\">Child 2</a></li>\n" +
                 "</ul>\n</p>"

    @project = Project.find(1)
    # child pages of the current wiki page
    assert_equal expected, textilizable("{{child_pages}}", :object => WikiPage.find(2).content)
    # child pages of another page
    assert_equal expected, textilizable("{{child_pages(Another_page)}}", :object => WikiPage.find(1).content)

    @project = Project.find(2)
    assert_equal expected, textilizable("{{child_pages(ecookbook:Another_page)}}", :object => WikiPage.find(1).content)
  end

  def test_macro_child_pages_with_option
    expected =  "<p><ul class=\"pages-hierarchy\">\n" +
                 "<li><a href=\"/projects/ecookbook/wiki/Another_page\">Another page</a>\n" +
                 "<ul class=\"pages-hierarchy\">\n" +
                 "<li><a href=\"/projects/ecookbook/wiki/Child_1\">Child 1</a></li>\n" +
                 "<li><a href=\"/projects/ecookbook/wiki/Child_2\">Child 2</a></li>\n" +
                 "</ul>\n</li>\n</ul>\n</p>"

    @project = Project.find(1)
    # child pages of the current wiki page
    assert_equal expected, textilizable("{{child_pages(parent=1)}}", :object => WikiPage.find(2).content)
    # child pages of another page
    assert_equal expected, textilizable("{{child_pages(Another_page, parent=1)}}", :object => WikiPage.find(1).content)

    @project = Project.find(2)
    assert_equal expected, textilizable("{{child_pages(ecookbook:Another_page, parent=1)}}", :object => WikiPage.find(1).content)
  end

  def test_macro_child_pages_without_wiki_page_should_fail
    assert_match /can be called from wiki pages only/, textilizable("{{child_pages}}")
  end

  def test_macro_thumbnail
    assert_equal '<p><a href="/attachments/17" class="thumbnail" title="testfile.PNG"><img alt="testfile.PNG" src="/attachments/thumbnail/17" /></a></p>',
      textilizable("{{thumbnail(testfile.png)}}", :object => Issue.find(14))
  end

  def test_macro_thumbnail_with_size
    assert_equal '<p><a href="/attachments/17" class="thumbnail" title="testfile.PNG"><img alt="testfile.PNG" src="/attachments/thumbnail/17/200" /></a></p>',
      textilizable("{{thumbnail(testfile.png, size=200)}}", :object => Issue.find(14))
  end

  def test_macro_thumbnail_with_title
    assert_equal '<p><a href="/attachments/17" class="thumbnail" title="Cool image"><img alt="testfile.PNG" src="/attachments/thumbnail/17" /></a></p>',
      textilizable("{{thumbnail(testfile.png, title=Cool image)}}", :object => Issue.find(14))
  end

  def test_macro_thumbnail_with_invalid_filename_should_fail
    assert_include 'test.png not found',
      textilizable("{{thumbnail(test.png)}}", :object => Issue.find(14))
  end

  def test_macros_should_not_be_executed_in_pre_tags
    text = <<-RAW
{{hello_world(foo)}}

<pre>
{{hello_world(pre)}}
!{{hello_world(pre)}}
</pre>

{{hello_world(bar)}}
RAW

    expected = <<-EXPECTED
<p>Hello world! Object: NilClass, Arguments: foo and no block of text.</p>

<pre>
{{hello_world(pre)}}
!{{hello_world(pre)}}
</pre>

<p>Hello world! Object: NilClass, Arguments: bar and no block of text.</p>
EXPECTED

    assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(text).gsub(%r{[\r\n\t]}, '')
  end

  def test_macros_should_be_escaped_in_pre_tags
    text = "<pre>{{hello_world(<tag>)}}</pre>"
    assert_equal "<pre>{{hello_world(&lt;tag&gt;)}}</pre>", textilizable(text)
  end

  def test_macros_should_not_mangle_next_macros_outputs
    text = '{{macro(2)}} !{{macro(2)}} {{hello_world(foo)}}'
    assert_equal '<p>{{macro(2)}} {{macro(2)}} Hello world! Object: NilClass, Arguments: foo and no block of text.</p>', textilizable(text)
  end

  def test_macros_with_text_should_not_mangle_following_macros
    text = <<-RAW
{{hello_world
Line of text
}}

{{hello_world
Another line of text
}}
RAW

    expected = <<-EXPECTED
<p>Hello world! Object: NilClass, Called with no argument and a 12 bytes long block of text.</p>
<p>Hello world! Object: NilClass, Called with no argument and a 20 bytes long block of text.</p>
EXPECTED

    assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(text).gsub(%r{[\r\n\t]}, '')
  end
end
