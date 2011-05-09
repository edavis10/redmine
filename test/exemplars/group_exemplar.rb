class Group < Principal
  generator_for :lastname, :method => :next_lastname

  def self.next_lastname
    @last_lastname ||= 'Group'
    @last_lastname.succ!
    @last_lastname
  end

end

# == Schema Information
#
# Table name: users
#
#  id                 :integer(4)      not null, primary key
#  login              :string(30)      default(""), not null
#  hashed_password    :string(40)      default(""), not null
#  firstname          :string(30)      default(""), not null
#  lastname           :string(30)      default(""), not null
#  mail               :string(60)      default(""), not null
#  admin              :boolean(1)      default(FALSE), not null
#  status             :integer(4)      default(1), not null
#  last_login_on      :datetime
#  language           :string(5)       default("")
#  auth_source_id     :integer(4)
#  created_on         :datetime
#  updated_on         :datetime
#  type               :string(255)
#  identity_url       :string(255)
#  mail_notification  :string(255)     default(""), not null
#  salt               :string(64)
#  invoicing_password :string(255)
#

