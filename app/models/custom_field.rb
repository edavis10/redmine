# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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

class CustomField < ActiveRecord::Base
  has_many :custom_values, :dependent => :delete_all
  acts_as_list :scope => 'type = \'#{self.class}\''
  serialize :possible_values
  
  validates_presence_of :name, :field_format
  validates_uniqueness_of :name, :scope => :type
  validates_length_of :name, :maximum => 30
  validates_format_of :name, :with => /^[\w\s\.\'\-]*$/i
  validates_inclusion_of :field_format, :in => Redmine::CustomFieldFormat.available_formats

  def initialize(attributes = nil)
    super
    self.possible_values ||= []
  end
  
  def before_validation
    # make sure these fields are not searchable
    self.searchable = false if %w(int float date bool).include?(field_format)
    true
  end
  
  def validate
    if self.field_format == "list"
      errors.add(:possible_values, :blank) if self.possible_values.nil? || self.possible_values.empty?
      errors.add(:possible_values, :invalid) unless self.possible_values.is_a? Array
    end
    
    # validate default value
    v = CustomValue.new(:custom_field => self.clone, :value => default_value, :customized => nil)
    v.custom_field.is_required = false
    errors.add(:default_value, :invalid) unless v.valid?
  end
  
  # Makes possible_values accept a multiline string
  def possible_values=(arg)
    if arg.is_a?(Array)
      write_attribute(:possible_values, arg.compact.collect(&:strip).select {|v| !v.blank?})
    else
      self.possible_values = arg.to_s.split(/[\n\r]+/)
    end
  end
  
  def cast_value(value)
    casted = nil
    unless value.blank?
      case field_format
      when 'string', 'text', 'list'
        casted = value
      when 'date'
        casted = begin; value.to_date; rescue; nil end
      when 'bool'
        casted = (value == '1' ? true : false)
      when 'int'
        casted = value.to_i
      when 'float'
        casted = value.to_f
      end
    end
    casted
  end
  
  # Returns a ORDER BY clause that can used to sort customized
  # objects by their value of the custom field.
  # Returns false, if the custom field can not be used for sorting.
  def order_statement
    case field_format
      when 'string', 'text', 'list', 'date', 'bool'
        # COALESCE is here to make sure that blank and NULL values are sorted equally
        "COALESCE((SELECT cv_sort.value FROM #{CustomValue.table_name} cv_sort" + 
          " WHERE cv_sort.customized_type='#{self.class.customized_class.name}'" +
          " AND cv_sort.customized_id=#{self.class.customized_class.table_name}.id" +
          " AND cv_sort.custom_field_id=#{id} LIMIT 1), '')"
      when 'int', 'float'
        # Make the database cast values into numeric
        # Postgresql will raise an error if a value can not be casted!
        # CustomValue validations should ensure that it doesn't occur
        "(SELECT CAST(cv_sort.value AS decimal(60,3)) FROM #{CustomValue.table_name} cv_sort" + 
          " WHERE cv_sort.customized_type='#{self.class.customized_class.name}'" +
          " AND cv_sort.customized_id=#{self.class.customized_class.table_name}.id" +
          " AND cv_sort.custom_field_id=#{id} AND cv_sort.value <> '' AND cv_sort.value IS NOT NULL LIMIT 1)"
      else
        nil
    end
  end

  def <=>(field)
    position <=> field.position
  end
  
  def self.customized_class
    self.name =~ /^(.+)CustomField$/
    begin; $1.constantize; rescue nil; end
  end
  
  # to move in project_custom_field
  def self.for_all
    find(:all, :conditions => ["is_for_all=?", true], :order => 'position')
  end
  
  def type_name
    nil
  end
end
