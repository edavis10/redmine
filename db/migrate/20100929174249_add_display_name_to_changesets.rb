class AddDisplayNameToChangesets < ActiveRecord::Migration
  def self.up
    add_column :changesets, :display_name, :string
  end

  def self.down
    remove_column :changesets, :display_name
  end
end
