class CustomValue < ActiveRecord::Base
  generator_for :custom_field, :method => :generate_custom_field

  def self.generate_custom_field
    CustomField.generate!
  end
end

# == Schema Information
#
# Table name: custom_values
#
#  id              :integer(4)      not null, primary key
#  customized_type :string(30)      default(""), not null
#  customized_id   :integer(4)      default(0), not null
#  custom_field_id :integer(4)      default(0), not null
#  value           :text
#

