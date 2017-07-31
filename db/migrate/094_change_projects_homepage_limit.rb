class ChangeProjectsHomepageLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :projects, :homepage, :string, :limit => nil, :default => ''
  end

  def self.down
    change_column :projects, :homepage, :string, :limit => 60, :default => ''
  end
end
