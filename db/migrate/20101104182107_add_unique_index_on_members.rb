class AddUniqueIndexOnMembers < ActiveRecord::Migration[4.2]
  def self.up
    # Clean and reassign MemberRole rows if needed
    MemberRole.where("member_id NOT IN (SELECT id FROM #{Member.table_name})").delete_all
    MemberRole.update_all("member_id =" +
      " (SELECT min(m2.id) FROM #{Member.table_name} m1, #{Member.table_name} m2" +
      " WHERE m1.user_id = m2.user_id AND m1.project_id = m2.project_id" +
      " AND m1.id = #{MemberRole.table_name}.member_id)")
    # Remove duplicates
    Member.connection.select_values("SELECT m.id FROM #{Member.table_name} m" +
      " WHERE m.id > (SELECT min(m1.id) FROM #{Member.table_name} m1 WHERE m1.user_id = m.user_id AND m1.project_id = m.project_id)").each do |i|
        Member.where(["id = ?", i]).delete_all
      end

    # Then add a unique index
    add_index :members, [:user_id, :project_id], :unique => true
  end

  def self.down
    remove_index :members, [:user_id, :project_id]
  end
end
