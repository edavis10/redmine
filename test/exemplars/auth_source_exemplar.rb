class AuthSource < ActiveRecord::Base
  generator_for :name, :method => :next_name

  def self.next_name
    @last_name ||= 'Auth0'
    @last_name.succ!
    @last_name
  end
end

# == Schema Information
#
# Table name: auth_sources
#
#  id                :integer(4)      not null, primary key
#  type              :string(30)      default(""), not null
#  name              :string(60)      default(""), not null
#  host              :string(60)
#  port              :integer(4)
#  account           :string(255)
#  account_password  :string(255)     default("")
#  base_dn           :string(255)
#  attr_login        :string(30)
#  attr_firstname    :string(30)
#  attr_lastname     :string(30)
#  attr_mail         :string(30)
#  onthefly_register :boolean(1)      default(FALSE), not null
#  tls               :boolean(1)      default(FALSE), not null
#

