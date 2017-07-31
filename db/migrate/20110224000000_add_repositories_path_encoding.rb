class AddRepositoriesPathEncoding < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :path_encoding, :string, :limit => 64, :default => nil
  end

  def self.down
    remove_column :repositories, :path_encoding
  end
end
