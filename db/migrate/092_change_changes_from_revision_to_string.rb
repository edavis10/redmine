class ChangeChangesFromRevisionToString < ActiveRecord::Migration[4.2]
  def self.up
    change_column :changes, :from_revision, :string
  end

  def self.down
    change_column :changes, :from_revision, :integer
  end
end
