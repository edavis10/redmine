class CreateComments < ActiveRecord::Migration[4.2]
  def self.up
    create_table :comments do |t|
      t.column :commented_type, :string, :limit => 30, :default => "", :null => false
      t.column :commented_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :comments, :text
      t.column :created_on, :datetime, :null => false
      t.column :updated_on, :datetime, :null => false
    end
  end

  def self.down
    drop_table :comments
  end
end
