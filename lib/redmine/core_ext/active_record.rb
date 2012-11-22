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

module ActiveRecord
  module FinderMethods
    def find_ids(*args)
      find_ids_with_associations
    end

    private
  
    def find_ids_with_associations
        join_dependency = construct_join_dependency_for_association_find
        relation = construct_relation_for_association_find_ids(join_dependency)
        rows = connection.select_all(relation, 'SQL', relation.bind_values)
        rows.map {|row| row["id"].to_i}
      rescue ThrowResult
        []
    end

    def construct_relation_for_association_find_ids(join_dependency)
      relation = except(:includes, :eager_load, :preload, :select).select("#{table_name}.id")
      apply_join_dependency(relation, join_dependency)
    end
  end
end
