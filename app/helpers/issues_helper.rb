# encoding: utf-8
#
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

module IssuesHelper
  include ApplicationHelper

  def issue_list(issues, &block)
    ancestors = []
    issues.each do |issue|
      while (ancestors.any? && !issue.is_descendant_of?(ancestors.last))
        ancestors.pop
      end
      yield issue, ancestors.size
      ancestors << issue unless issue.leaf?
    end
  end

  # Renders a HTML/CSS tooltip
  #
  # To use, a trigger div is needed.  This is a div with the class of "tooltip"
  # that contains this method wrapped in a span with the class of "tip"
  #
  #    <div class="tooltip"><%= link_to_issue(issue) %>
  #      <span class="tip"><%= render_issue_tooltip(issue) %></span>
  #    </div>
  #
  def render_issue_tooltip(issue)
    @cached_label_status ||= l(:field_status)
    @cached_label_start_date ||= l(:field_start_date)
    @cached_label_due_date ||= l(:field_due_date)
    @cached_label_assigned_to ||= l(:field_assigned_to)
    @cached_label_priority ||= l(:field_priority)
    @cached_label_project ||= l(:field_project)

    link_to_issue(issue) + "<br /><br />".html_safe +
      "<strong>#{@cached_label_project}</strong>: #{link_to_project(issue.project)}<br />".html_safe +
      "<strong>#{@cached_label_status}</strong>: #{h(issue.status.name)}<br />".html_safe +
      "<strong>#{@cached_label_start_date}</strong>: #{format_date(issue.start_date)}<br />".html_safe +
      "<strong>#{@cached_label_due_date}</strong>: #{format_date(issue.due_date)}<br />".html_safe +
      "<strong>#{@cached_label_assigned_to}</strong>: #{h(issue.assigned_to)}<br />".html_safe +
      "<strong>#{@cached_label_priority}</strong>: #{h(issue.priority.name)}".html_safe
  end

  def issue_heading(issue)
    h("#{issue.tracker} ##{issue.id}")
  end

  def render_issue_subject_with_tree(issue)
    s = ''
    ancestors = issue.root? ? [] : issue.ancestors.visible.all
    ancestors.each do |ancestor|
      s << '<div>' + content_tag('p', link_to_issue(ancestor))
    end
    s << '<div>'
    subject = h(issue.subject)
    if issue.is_private?
      subject = content_tag('span', l(:field_is_private), :class => 'private') + ' ' + subject
    end
    s << content_tag('h3', subject)
    s << '</div>' * (ancestors.size + 1)
    s.html_safe
  end

  def render_descendants_tree(issue)
    s = '<form><table class="list issues">'
    issue_list(issue.descendants.visible.sort_by(&:lft)) do |child, level|
      s << content_tag('tr',
             content_tag('td', check_box_tag("ids[]", child.id, false, :id => nil), :class => 'checkbox') +
             content_tag('td', link_to_issue(child, :truncate => 60), :class => 'subject') +
             content_tag('td', h(child.status)) +
             content_tag('td', link_to_user(child.assigned_to)) +
             content_tag('td', progress_bar(child.done_ratio, :width => '80px')),
             :class => "issue issue-#{child.id} hascontextmenu #{level > 0 ? "idnt idnt-#{level}" : nil}")
    end
    s << '</table></form>'
    s.html_safe
  end

  class IssueFieldsRows
    include ActionView::Helpers::TagHelper

    def initialize
      @left = []
      @right = []
    end

    def left(*args)
      args.any? ? @left << cells(*args) : @left
    end

    def right(*args)
      args.any? ? @right << cells(*args) : @right
    end

    def size
      @left.size > @right.size ? @left.size : @right.size
    end

    def to_html
      html = ''.html_safe
      blank = content_tag('th', '') + content_tag('td', '')
      size.times do |i|
        left = @left[i] || blank
        right = @right[i] || blank
        html << content_tag('tr', left + right)
      end
      html
    end

    def cells(label, text, options={})
      content_tag('th', "#{label}:", options) + content_tag('td', text, options)
    end
  end

  def issue_fields_rows
    r = IssueFieldsRows.new
    yield r
    r.to_html
  end

  def render_custom_fields_rows(issue)
    return if issue.custom_field_values.empty?
    ordered_values = []
    half = (issue.custom_field_values.size / 2.0).ceil
    half.times do |i|
      ordered_values << issue.custom_field_values[i]
      ordered_values << issue.custom_field_values[i + half]
    end
    s = "<tr>\n"
    n = 0
    ordered_values.compact.each do |value|
      s << "</tr>\n<tr>\n" if n > 0 && (n % 2) == 0
      s << "\t<th>#{ h(value.custom_field.name) }:</th><td>#{ simple_format_without_paragraph(h(show_value(value))) }</td>\n"
      n += 1
    end
    s << "</tr>\n"
    s.html_safe
  end

  def issues_destroy_confirmation_message(issues)
    issues = [issues] unless issues.is_a?(Array)
    message = l(:text_issues_destroy_confirmation)
    descendant_count = issues.inject(0) {|memo, i| memo += (i.right - i.left - 1)/2}
    if descendant_count > 0
      issues.each do |issue|
        next if issue.root?
        issues.each do |other_issue|
          descendant_count -= 1 if issue.is_descendant_of?(other_issue)
        end
      end
      if descendant_count > 0
        message << "\n" + l(:text_issues_destroy_descendants_confirmation, :count => descendant_count)
      end
    end
    message
  end

  def sidebar_queries
    unless @sidebar_queries
      @sidebar_queries = Query.visible.all(
        :order => "#{Query.table_name}.name ASC",
        # Project specific queries and global queries
        :conditions => (@project.nil? ? ["project_id IS NULL"] : ["project_id IS NULL OR project_id = ?", @project.id])
      )
    end
    @sidebar_queries
  end

  def query_links(title, queries)
    # links to #index on issues/show
    url_params = controller_name == 'issues' ? {:controller => 'issues', :action => 'index', :project_id => @project} : params

    content_tag('h3', h(title)) +
      queries.collect {|query|
          css = 'query'
          css << ' selected' if query == @query
          link_to(h(query.name), url_params.merge(:query_id => query), :class => css)
        }.join('<br />').html_safe
  end

  def render_sidebar_queries
    out = ''.html_safe
    queries = sidebar_queries.select {|q| !q.is_public?}
    out << query_links(l(:label_my_queries), queries) if queries.any?
    queries = sidebar_queries.select {|q| q.is_public?}
    out << query_links(l(:label_query_plural), queries) if queries.any?
    out
  end

  # Returns the textual representation of a journal details
  # as an array of strings
  def details_to_strings(details, no_html=false, options={})
    options[:only_path] = (options[:only_path] == false ? false : true)
    strings = []
    values_by_field = {}
    details.each do |detail|
      if detail.property == 'cf'
        field_id = detail.prop_key
        field = CustomField.find_by_id(field_id)
        if field && field.multiple?
          values_by_field[field_id] ||= {:added => [], :deleted => []}
          if detail.old_value
            values_by_field[field_id][:deleted] << detail.old_value
          end
          if detail.value
            values_by_field[field_id][:added] << detail.value
          end
          next
        end
      end
      strings << show_detail(detail, no_html, options)
    end
    values_by_field.each do |field_id, changes|
      detail = JournalDetail.new(:property => 'cf', :prop_key => field_id)
      if changes[:added].any?
        detail.value = changes[:added]
        strings << show_detail(detail, no_html, options)
      elsif changes[:deleted].any?
        detail.old_value = changes[:deleted]
        strings << show_detail(detail, no_html, options)
      end
    end
    strings
  end

  # Returns the textual representation of a single journal detail
  def show_detail(detail, no_html=false, options={})
    multiple = false
    case detail.property
    when 'attr'
      field = detail.prop_key.to_s.gsub(/\_id$/, "")
      label = l(("field_" + field).to_sym)
      case detail.prop_key
      when 'due_date', 'start_date'
        value = format_date(detail.value.to_date) if detail.value
        old_value = format_date(detail.old_value.to_date) if detail.old_value

      when 'project_id', 'status_id', 'tracker_id', 'assigned_to_id',
            'priority_id', 'category_id', 'fixed_version_id'
        value = find_name_by_reflection(field, detail.value)
        old_value = find_name_by_reflection(field, detail.old_value)

      when 'estimated_hours'
        value = "%0.02f" % detail.value.to_f unless detail.value.blank?
        old_value = "%0.02f" % detail.old_value.to_f unless detail.old_value.blank?

      when 'parent_id'
        label = l(:field_parent_issue)
        value = "##{detail.value}" unless detail.value.blank?
        old_value = "##{detail.old_value}" unless detail.old_value.blank?

      when 'is_private'
        value = l(detail.value == "0" ? :general_text_No : :general_text_Yes) unless detail.value.blank?
        old_value = l(detail.old_value == "0" ? :general_text_No : :general_text_Yes) unless detail.old_value.blank?
      end
    when 'cf'
      custom_field = CustomField.find_by_id(detail.prop_key)
      if custom_field
        multiple = custom_field.multiple?
        label = custom_field.name
        value = format_value(detail.value, custom_field.field_format) if detail.value
        old_value = format_value(detail.old_value, custom_field.field_format) if detail.old_value
      end
    when 'attachment'
      label = l(:label_attachment)
    end
    call_hook(:helper_issues_show_detail_after_setting,
              {:detail => detail, :label => label, :value => value, :old_value => old_value })

    label ||= detail.prop_key
    value ||= detail.value
    old_value ||= detail.old_value

    unless no_html
      label = content_tag('strong', label)
      old_value = content_tag("i", h(old_value)) if detail.old_value
      old_value = content_tag("del", old_value) if detail.old_value and detail.value.blank?
      if detail.property == 'attachment' && !value.blank? && atta = Attachment.find_by_id(detail.prop_key)
        # Link to the attachment if it has not been removed
        value = link_to_attachment(atta, :download => true, :only_path => options[:only_path])
        if options[:only_path] != false && atta.is_text?
          value += link_to(
                       image_tag('magnifier.png'),
                       :controller => 'attachments', :action => 'show',
                       :id => atta, :filename => atta.filename
                     )
        end
      else
        value = content_tag("i", h(value)) if value
      end
    end

    if detail.property == 'attr' && detail.prop_key == 'description'
      s = l(:text_journal_changed_no_detail, :label => label)
      unless no_html
        diff_link = link_to 'diff',
          {:controller => 'journals', :action => 'diff', :id => detail.journal_id,
           :detail_id => detail.id, :only_path => options[:only_path]},
          :title => l(:label_view_diff)
        s << " (#{ diff_link })"
      end
      s.html_safe
    elsif detail.value.present?
      case detail.property
      when 'attr', 'cf'
        if detail.old_value.present?
          l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
        elsif multiple
          l(:text_journal_added, :label => label, :value => value).html_safe
        else
          l(:text_journal_set_to, :label => label, :value => value).html_safe
        end
      when 'attachment'
        l(:text_journal_added, :label => label, :value => value).html_safe
      end
    else
      l(:text_journal_deleted, :label => label, :old => old_value).html_safe
    end
  end

  # Find the name of an associated record stored in the field attribute
  def find_name_by_reflection(field, id)
    association = Issue.reflect_on_association(field.to_sym)
    if association
      record = association.class_name.constantize.find_by_id(id)
      return record.name if record
    end
  end

  # Renders issue children recursively
  def render_api_issue_children(issue, api)
    return if issue.leaf?
    api.array :children do
      issue.children.each do |child|
        api.issue(:id => child.id) do
          api.tracker(:id => child.tracker_id, :name => child.tracker.name) unless child.tracker.nil?
          api.subject child.subject
          render_api_issue_children(child, api)
        end
      end
    end
  end

  def issues_to_csv(issues, project, query, options={})
    decimal_separator = l(:general_csv_decimal_separator)
    encoding = l(:general_csv_encoding)
    columns = (options[:columns] == 'all' ? query.available_columns : query.columns)

    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      csv << [ "#" ] + columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) } +
        (options[:description] ? [Redmine::CodesetUtil.from_utf8(l(:field_description), encoding)] : [])

      # csv lines
      issues.each do |issue|
        col_values = columns.collect do |column|
          s = if column.is_a?(QueryCustomFieldColumn)
            cv = issue.custom_field_values.detect {|v| v.custom_field_id == column.custom_field.id}
            show_value(cv)
          else
            value = column.value(issue)
            if value.is_a?(Date)
              format_date(value)
            elsif value.is_a?(Time)
              format_time(value)
            elsif value.is_a?(Float)
              ("%.2f" % value).gsub('.', decimal_separator)
            else
              value
            end
          end
          s.to_s
        end
        csv << [ issue.id.to_s ] + col_values.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) } +
          (options[:description] ? [Redmine::CodesetUtil.from_utf8(issue.description, encoding)] : [])
      end
    end
    export
  end
end
