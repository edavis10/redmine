class DocumentCategory < Enumeration
  generator_for :name, :method => :next_name
  generator_for :type => 'DocumentCategory'

  def self.next_name
    @last_name ||= 'DocumentCategory0'
    @last_name.succ!
    @last_name
  end
end

# == Schema Information
#
# Table name: enumerations
#
#  id         :integer(4)      not null, primary key
#  name       :string(30)      default(""), not null
#  position   :integer(4)      default(1)
#  is_default :boolean(1)      default(FALSE), not null
#  type       :string(255)
#  active     :boolean(1)      default(TRUE), not null
#  project_id :integer(4)
#  parent_id  :integer(4)
#  opt        :string(4)
#

