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

require File.expand_path('../../test_helper', __FILE__)

class CustomFieldTest < ActiveSupport::TestCase
  fixtures :custom_fields

  def test_create
    field = UserCustomField.new(:name => 'Money money money', :field_format => 'float')
    assert field.save
  end

  def test_before_validation
    field = CustomField.new(:name => 'test_before_validation', :field_format => 'int')
    field.searchable = true
    assert field.save
    assert_equal false, field.searchable
    field.searchable = true
    assert field.save
    assert_equal false, field.searchable
  end

  def test_regexp_validation
    field = IssueCustomField.new(:name => 'regexp', :field_format => 'text', :regexp => '[a-z0-9')
    assert !field.save
    assert_include I18n.t('activerecord.errors.messages.invalid'),
                   field.errors[:regexp]
    field.regexp = '[a-z0-9]'
    assert field.save
  end

  def test_default_value_should_be_validated
    field = CustomField.new(:name => 'Test', :field_format => 'int')
    field.default_value = 'abc'
    assert !field.valid?
    field.default_value = '6'
    assert field.valid?
  end

  def test_default_value_should_not_be_validated_when_blank
    field = CustomField.new(:name => 'Test', :field_format => 'list', :possible_values => ['a', 'b'], :is_required => true, :default_value => '')
    assert field.valid?
  end

  def test_possible_values_should_accept_an_array
    field = CustomField.new
    field.possible_values = ["One value", ""]
    assert_equal ["One value"], field.possible_values
  end

  def test_possible_values_should_accept_a_string
    field = CustomField.new
    field.possible_values = "One value"
    assert_equal ["One value"], field.possible_values
  end

  def test_possible_values_should_accept_a_multiline_string
    field = CustomField.new
    field.possible_values = "One value\nAnd another one  \r\n \n"
    assert_equal ["One value", "And another one"], field.possible_values
  end

  if "string".respond_to?(:encoding)
    def test_possible_values_stored_as_binary_should_be_utf8_encoded
      field = CustomField.find(11)
      assert_kind_of Array, field.possible_values
      assert field.possible_values.size > 0
      field.possible_values.each do |value|
        assert_equal "UTF-8", value.encoding.name
      end
    end
  end

  def test_destroy
    field = CustomField.find(1)
    assert field.destroy
  end

  def test_new_subclass_instance_should_return_an_instance
    f = CustomField.new_subclass_instance('IssueCustomField')
    assert_kind_of IssueCustomField, f
  end

  def test_new_subclass_instance_should_set_attributes
    f = CustomField.new_subclass_instance('IssueCustomField', :name => 'Test')
    assert_kind_of IssueCustomField, f
    assert_equal 'Test', f.name
  end

  def test_new_subclass_instance_with_invalid_class_name_should_return_nil
    assert_nil CustomField.new_subclass_instance('WrongClassName')
  end

  def test_new_subclass_instance_with_non_subclass_name_should_return_nil
    assert_nil CustomField.new_subclass_instance('Project')
  end

  def test_string_field_validation_with_blank_value
    f = CustomField.new(:field_format => 'string')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')

    f.is_required = true
    assert !f.valid_field_value?(nil)
    assert !f.valid_field_value?('')
  end

  def test_string_field_validation_with_min_and_max_lengths
    f = CustomField.new(:field_format => 'string', :min_length => 2, :max_length => 5)

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?('a' * 2)
    assert !f.valid_field_value?('a')
    assert !f.valid_field_value?('a' * 6)
  end

  def test_string_field_validation_with_regexp
    f = CustomField.new(:field_format => 'string', :regexp => '^[A-Z0-9]*$')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?('ABC')
    assert !f.valid_field_value?('abc')
  end

  def test_date_field_validation
    f = CustomField.new(:field_format => 'date')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?('1975-07-14')
    assert !f.valid_field_value?('1975-07-33')
    assert !f.valid_field_value?('abc')
  end

  def test_list_field_validation
    f = CustomField.new(:field_format => 'list', :possible_values => ['value1', 'value2'])

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?('value2')
    assert !f.valid_field_value?('abc')
  end

  def test_int_field_validation
    f = CustomField.new(:field_format => 'int')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?('123')
    assert f.valid_field_value?('+123')
    assert f.valid_field_value?('-123')
    assert !f.valid_field_value?('6abc')
  end

  def test_float_field_validation
    f = CustomField.new(:field_format => 'float')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?('11.2')
    assert f.valid_field_value?('-6.250')
    assert f.valid_field_value?('5')
    assert !f.valid_field_value?('6abc')
  end

  def test_multi_field_validation
    f = CustomField.new(:field_format => 'list', :multiple => 'true', :possible_values => ['value1', 'value2'])

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert f.valid_field_value?([])
    assert f.valid_field_value?([nil])
    assert f.valid_field_value?([''])

    assert f.valid_field_value?('value2')
    assert !f.valid_field_value?('abc')

    assert f.valid_field_value?(['value2'])
    assert !f.valid_field_value?(['abc'])

    assert f.valid_field_value?(['', 'value2'])
    assert !f.valid_field_value?(['', 'abc'])

    assert f.valid_field_value?(['value1', 'value2'])
    assert !f.valid_field_value?(['value1', 'abc'])
  end

  def test_value_class_should_return_the_class_used_for_fields_values
    assert_equal User, CustomField.new(:field_format => 'user').value_class
    assert_equal Version, CustomField.new(:field_format => 'version').value_class
  end

  def test_value_class_should_return_nil_for_other_fields
    assert_nil CustomField.new(:field_format => 'text').value_class
    assert_nil CustomField.new.value_class
  end
end
