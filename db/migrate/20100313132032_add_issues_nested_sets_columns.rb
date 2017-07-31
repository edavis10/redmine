class AddIssuesNestedSetsColumns < ActiveRecord::Migration[4.2]
  def self.up
    add_column :issues, :parent_id, :integer, :default => nil
    add_column :issues, :root_id, :integer, :default => nil
    add_column :issues, :lft, :integer, :default => nil
    add_column :issues, :rgt, :integer, :default => nil

    Issue.update_all("parent_id = NULL, root_id = id, lft = 1, rgt = 2")
  end

  def self.down
    remove_column :issues, :parent_id
    remove_column :issues, :root_id
    remove_column :issues, :lft
    remove_column :issues, :rgt
  end
end
