# Redmine - project management software
# Copyright (C) 2006-2009  Jean-Philippe Lang
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

module SettingsHelper
  def administration_settings_tabs
    tabs = [{:name => 'general', :partial => 'settings/general', :label => :label_general},
            {:name => 'display', :partial => 'settings/display', :label => :label_display},
            {:name => 'authentication', :partial => 'settings/authentication', :label => :label_authentication},
            {:name => 'projects', :partial => 'settings/projects', :label => :label_project_plural},
            {:name => 'issues', :partial => 'settings/issues', :label => :label_issue_tracking},
            {:name => 'notifications', :partial => 'settings/notifications', :label => :field_mail_notification},
            {:name => 'mail_handler', :partial => 'settings/mail_handler', :label => :label_incoming_emails},
            {:name => 'repositories', :partial => 'settings/repositories', :label => :label_repository_plural}
            ]
  end
  
  def setting_select(setting, choices, options={})
    if blank_text = options.delete(:blank)
      choices = [[blank_text.is_a?(Symbol) ? l(blank_text) : blank_text, '']] + choices
    end
    setting_label(setting, options) +
      select_tag("settings[#{setting}]", options_for_select(choices, Setting.send(setting).to_s), options)
  end
  
  def setting_multiselect(setting, choices, options={})
    setting_values = Setting.send(setting)
    setting_values = [] unless setting_values.is_a?(Array)
      
    setting_label(setting, options) +
      hidden_field_tag("settings[#{setting}][]", '') +
      choices.collect do |choice|
        text, value = (choice.is_a?(Array) ? choice : [choice, choice]) 
        content_tag('label',
          check_box_tag("settings[#{setting}][]", value, Setting.send(setting).include?(value)) + text.to_s,
          :class => 'block'
        )
      end.join
  end
  
  def setting_text_field(setting, options={})
    setting_label(setting, options) +
      text_field_tag("settings[#{setting}]", Setting.send(setting), options)
  end
  
  def setting_text_area(setting, options={})
    setting_label(setting, options) +
      text_area_tag("settings[#{setting}]", Setting.send(setting), options)
  end
  
  def setting_check_box(setting, options={})
    setting_label(setting, options) +
      hidden_field_tag("settings[#{setting}]", 0) +
      check_box_tag("settings[#{setting}]", 1, Setting.send("#{setting}?"), options)
  end
  
  def setting_label(setting, options={})
    label = options.delete(:label)
    label != false ? content_tag("label", l(label || "setting_#{setting}")) : ''
  end

  # Renders a notification field for a Redmine::Notifiable option
  def notification_field(notifiable)
    return content_tag(:label,
                       check_box_tag('settings[notified_events][]',
                                     notifiable.name,
                                     Setting.notified_events.include?(notifiable.name)) +
                         l_or_humanize(notifiable.name, :prefix => 'label_'),
                       :class => notifiable.parent.present? ? "parent" : '')
  end
end
