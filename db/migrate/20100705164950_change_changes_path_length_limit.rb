class ChangeChangesPathLengthLimit < ActiveRecord::Migration
  def self.up
<<<<<<< HEAD
    # these are two steps to please MySQL 5 on Win32
    change_column :changes, :path, :text, :default => nil, :null => true
    change_column :changes, :path, :text, :null => false
    
=======
    change_column :changes, :path, :text, :null => false
>>>>>>> Force the default value of path to be set on the Change model class. This is needed because MySQL does not support default values on text columns (Error introduced in r3828, #5771)
    change_column :changes, :from_path, :text
  end

  def self.down
    change_column :changes, :path, :string, :default => "", :null => false
    change_column :changes, :from_path, :string
  end
end
