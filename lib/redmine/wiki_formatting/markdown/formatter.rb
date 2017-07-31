# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require 'cgi'

module Redmine
  module WikiFormatting
    module Markdown
      class HTML < Redcarpet::Render::HTML
        include ActionView::Helpers::TagHelper
        include Redmine::Helpers::URL

        def link(link, title, content)
          return nil unless uri_with_safe_scheme?(link)

          css = nil
          unless link && link.starts_with?('/')
            css = 'external'
          end
          content_tag('a', content.to_s.html_safe, :href => link, :title => title, :class => css)
        end

        def block_code(code, language)
          if language.present? && Redmine::SyntaxHighlighting.language_supported?(language)
            "<pre><code class=\"#{CGI.escapeHTML language} syntaxhl\">" +
              Redmine::SyntaxHighlighting.highlight_by_language(code, language) +
              "</code></pre>"
          else
            "<pre>" + CGI.escapeHTML(code) + "</pre>"
          end
        end

        def image(link, title, alt_text)
          return unless uri_with_safe_scheme?(link)

          tag('img', :src => link, :alt => alt_text || "", :title => title)
        end
      end

      class Formatter
        def initialize(text)
          @text = text
        end

        def to_html(*args)
          html = formatter.render(@text)
          # restore wiki links eg. [[Foo]]
          html.gsub!(%r{\[<a href="(.*?)">(.*?)</a>\]}) do
            "[[#{$2}]]"
          end
          # restore Redmine links with double-quotes, eg. version:"1.0"
          html.gsub!(/(\w):&quot;(.+?)&quot;/) do
            "#{$1}:\"#{$2}\""
          end
          # restore user links with @ in login name eg. [@jsmith@somenet.foo]
          html.gsub!(%r{[@\A]<a href="mailto:(.*?)">(.*?)</a>}) do
            "@#{$2}"
          end
          html
        end

        def get_section(index)
          section = extract_sections(index)[1]
          hash = Digest::MD5.hexdigest(section)
          return section, hash
        end

        def update_section(index, update, hash=nil)
          t = extract_sections(index)
          if hash.present? && hash != Digest::MD5.hexdigest(t[1])
            raise Redmine::WikiFormatting::StaleSectionError
          end
          t[1] = update unless t[1].blank?
          t.reject(&:blank?).join "\n\n"
        end

        def extract_sections(index)
          sections = ['', '', '']
          offset = 0
          i = 0
          l = 1
          inside_pre = false
          @text.split(/(^(?:.+\r?\n\r?(?:\=+|\-+)|#+.+|~~~.*)\s*$)/).each do |part|
            level = nil
            if part =~ /\A~{3,}(\S+)?\s*$/
              if $1
                if !inside_pre
                  inside_pre = true
                end
              else
                inside_pre = !inside_pre
              end
            elsif inside_pre
              # nop
            elsif part =~ /\A(#+).+/
              level = $1.size
            elsif part =~ /\A.+\r?\n\r?(\=+|\-+)\s*$/
              level = $1.include?('=') ? 1 : 2
            end
            if level
              i += 1
              if offset == 0 && i == index
                # entering the requested section
                offset = 1
                l = level
              elsif offset == 1 && i > index && level <= l
                # leaving the requested section
                offset = 2
              end
            end
            sections[offset] << part
          end
          sections.map(&:strip)
        end

        private

        def formatter
          @@formatter ||= Redcarpet::Markdown.new(
            Redmine::WikiFormatting::Markdown::HTML.new(
              :filter_html => true,
              :hard_wrap => true
            ),
            :autolink => true,
            :fenced_code_blocks => true,
            :space_after_headers => true,
            :tables => true,
            :strikethrough => true,
            :superscript => true,
            :no_intra_emphasis => true,
            :footnotes => true
          )
        end
      end
    end
  end
end
