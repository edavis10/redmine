# redMine - project management software
# Copyright (C) 2006-2010  Jean-Philippe Lang
# Copyright (C) 2010 Yuya Nishihara <yuya@tcha.org>
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

require 'delegate'
require 'iconv'

module Redmine
  module Scm
    module Adapters
      # wraps scm adapter to convert path encodings
      class PathEncodableWrapper < SimpleDelegator  # :nodoc:
        def initialize(scm, path_encoding)
          super(scm)
          @path_encoding = path_encoding
        end

        def entry(path=nil, identifier=nil)
          convert_entry!(super(to_scm_path(path), identifier))
        end

        def entries(path=nil, identifier=nil)
          convert_entries!(super(to_scm_path(path), identifier))
        end

        def properties(path, identifier=nil)
          super(to_scm_path(path), identifier)
        end

        def revisions(path=nil, identifier_from=nil, identifier_to=nil, options={})
          convert_revisions!(super(to_scm_path(path), identifier_from, identifier_to, options))
        end

        def diff(path, identifier_from, identifier_to=nil)
          super(to_scm_path(path), identifier_from, identifier_to)
        end

        def cat(path, identifier=nil)
          super(to_scm_path(path), identifier)
        end

        def annotate(path, identifier=nil)
          super(to_scm_path(path), identifier)
        end

        private

        def convert_entry!(entry)
          return unless entry
          entry.name = from_scm_path(entry.name)
          entry.path = from_scm_path(entry.path)
          entry
        end

        def convert_entries!(entries)
          return unless entries
          entries.each { |e| convert_entry!(e) }
          entries
        end

        def convert_revisions!(revisions)
          return unless revisions
          revisions.each do |rev|
            next unless rev.paths
            rev.paths.each do |e|
              e[:path] = from_scm_path(e[:path])
              e[:from_path] = from_scm_path(e[:from_path])
            end
          end
          revisions
        end

        # convert repository path string to utf-8
        def from_scm_path(s)
          return unless s
          begin
            Iconv.conv('UTF-8', @path_encoding, s)
          rescue Iconv::Failure => err
            raise CommandFailed, "failed to convert path from #{@path_encoding} to UTF-8. #{err}"
          end
        end

        # convert utf-8 path string to repository encoding
        def to_scm_path(s)
          return unless s
          begin
            Iconv.conv(@path_encoding, 'UTF-8', s)
          rescue Iconv::Failure => err
            raise CommandFailed, "failed to convert path from UTF-8 to #{@path_encoding}. #{err}"
          end
        end
      end
    end
  end
end
