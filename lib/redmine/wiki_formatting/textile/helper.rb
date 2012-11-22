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

module Redmine
  module WikiFormatting
    module Textile
      module Helper
        def wikitoolbar_for(field_id)
          heads_for_wiki_formatter
          # Is there a simple way to link to a public resource?
          url = "#{Redmine::Utils.relative_url_root}/help/wiki_syntax.html"
          help_link = link_to(l(:setting_text_formatting), url,
            :onclick => "window.open(\"#{ url }\", \"\", \"resizable=yes, location=no, width=300, height=640, menubar=no, status=no, scrollbars=yes\"); return false;")

          javascript_tag("var wikiToolbar = new jsToolBar(document.getElementById('#{field_id}')); wikiToolbar.setHelpLink('#{escape_javascript help_link}'); wikiToolbar.draw();")
        end

        def initial_page_content(page)
          "h1. #{@page.pretty_title}"
        end

        def heads_for_wiki_formatter
          unless @heads_for_wiki_formatter_included
            content_for :header_tags do
              javascript_include_tag('jstoolbar/jstoolbar-textile.min') +
              javascript_include_tag("jstoolbar/lang/jstoolbar-#{current_language.to_s.downcase}") +
              stylesheet_link_tag('jstoolbar')
            end
            @heads_for_wiki_formatter_included = true
          end
        end
      end
    end
  end
end
