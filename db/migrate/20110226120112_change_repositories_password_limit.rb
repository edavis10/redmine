class ChangeRepositoriesPasswordLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :repositories, :password, :string, :limit => nil, :default => ''
  end

  def self.down
    change_column :repositories, :password, :string, :limit => 60, :default => ''
  end
end
