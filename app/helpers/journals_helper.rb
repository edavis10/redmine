# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

module JournalsHelper
  def render_notes(issue, journal, options={})
    content = ''
    editable = User.current.logged? && (User.current.allowed_to?(:edit_issue_notes, issue.project) || (journal.user == User.current && User.current.allowed_to?(:edit_own_issue_notes, issue.project)))
    links = []
    if !journal.notes.blank?
      links << link_to_remote(image_tag('comment.png'),
                              { :url => {:controller => 'journals', :action => 'new', :id => issue, :journal_id => journal} },
                              :title => l(:button_quote)) if options[:reply_links]
      links << link_to_in_place_notes_editor(image_tag('edit.png'), "journal-#{journal.id}-notes", 
                                             { :controller => 'journals', :action => 'edit', :id => journal },
                                                :title => l(:button_edit)) if editable
    end
    content << content_tag('div', links.join(' '), :class => 'contextual') unless links.empty?
    content << textilizable(journal, :notes)
    css_classes = "wiki"
    css_classes << " editable" if editable
    content_tag('div', content, :id => "journal-#{journal.id}-notes", :class => css_classes)
  end
  
  def link_to_in_place_notes_editor(text, field_id, url, options={})
    onclick = "new Ajax.Request('#{url_for(url)}', {asynchronous:true, evalScripts:true, method:'get'}); return false;"
    link_to text, '#', options.merge(:onclick => onclick)
  end
end
