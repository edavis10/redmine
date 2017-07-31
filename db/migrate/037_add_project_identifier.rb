class AddProjectIdentifier < ActiveRecord::Migration[4.2]
  def self.up
    add_column :projects, :identifier, :string, :limit => 20
  end

  def self.down
    remove_column :projects, :identifier
  end
end
