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

class AuthSourceLdapTest < ActiveSupport::TestCase
  include Redmine::I18n
  fixtures :auth_sources

  def setup
  end

  def test_create
    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName')
    assert a.save
  end

  def test_should_strip_ldap_attributes
    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName',
                           :attr_firstname => 'givenName ')
    assert a.save
    assert_equal 'givenName', a.reload.attr_firstname
  end

  def test_replace_port_zero_to_389
    a = AuthSourceLdap.new(
           :name => 'My LDAP', :host => 'ldap.example.net', :port => 0,
           :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName',
           :attr_firstname => 'givenName ')
    assert a.save
    assert_equal 389, a.port
  end

  def test_filter_should_be_validated
    set_language_if_valid 'en'

    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :attr_login => 'sn')
    a.filter = "(mail=*@redmine.org"
    assert !a.valid?
    assert_include "LDAP filter is invalid", a.errors.full_messages

    a.filter = "(mail=*@redmine.org)"
    assert a.valid?
  end

  if ldap_configured?
    context '#authenticate' do
      setup do
        @auth = AuthSourceLdap.find(1)
        @auth.update_attribute :onthefly_register, true
      end

      context 'with a valid LDAP user' do
        should 'return the user attributes' do
          attributes =  @auth.authenticate('example1','123456')
          assert attributes.is_a?(Hash), "An hash was not returned"
          assert_equal 'Example', attributes[:firstname]
          assert_equal 'One', attributes[:lastname]
          assert_equal 'example1@redmine.org', attributes[:mail]
          assert_equal @auth.id, attributes[:auth_source_id]
          attributes.keys.each do |attribute|
            assert User.new.respond_to?("#{attribute}="), "Unexpected :#{attribute} attribute returned"
          end
        end
      end

      context 'with an invalid LDAP user' do
        should 'return nil' do
          assert_equal nil, @auth.authenticate('nouser','123456')
        end
      end

      context 'without a login' do
        should 'return nil' do
          assert_equal nil, @auth.authenticate('','123456')
        end
      end

      context 'without a password' do
        should 'return nil' do
          assert_equal nil, @auth.authenticate('edavis','')
        end
      end

      context 'without filter' do
        should 'return any user' do
          assert @auth.authenticate('example1','123456')
          assert @auth.authenticate('edavis', '123456')
        end
      end

      context 'with filter' do
        setup do
          @auth.filter = "(mail=*@redmine.org)"
        end

        should 'return user who matches the filter only' do
          assert @auth.authenticate('example1','123456')
          assert_nil @auth.authenticate('edavis', '123456')
        end
      end
    end

    def test_authenticate_should_timeout
      auth_source = AuthSourceLdap.find(1)
      auth_source.timeout = 1
      def auth_source.initialize_ldap_con(*args); sleep(5); end

      assert_raise AuthSourceTimeoutException do
        auth_source.authenticate 'example1', '123456'
      end
    end
  else
    puts '(Test LDAP server not configured)'
  end
end
