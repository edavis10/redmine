class CustomField < ActiveRecord::Base
  generator_for :name, :method => :next_name
  generator_for :field_format => 'string'

  def self.next_name
    @last_name ||= 'CustomField0'
    @last_name.succ!
    @last_name
  end
end

# == Schema Information
#
# Table name: custom_fields
#
#  id              :integer(4)      not null, primary key
#  type            :string(30)      default(""), not null
#  name            :string(30)      default(""), not null
#  field_format    :string(30)      default(""), not null
#  possible_values :text
#  regexp          :string(255)     default("")
#  min_length      :integer(4)      default(0), not null
#  max_length      :integer(4)      default(0), not null
#  is_required     :boolean(1)      default(FALSE), not null
#  is_for_all      :boolean(1)      default(FALSE), not null
#  is_filter       :boolean(1)      default(FALSE), not null
#  position        :integer(4)      default(1)
#  searchable      :boolean(1)      default(FALSE)
#  default_value   :text
#  editable        :boolean(1)      default(TRUE)
#  visible         :boolean(1)      default(TRUE), not null
#

