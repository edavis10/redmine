class AddActivityIndexes < ActiveRecord::Migration
  def self.up
    add_index :journals, :created_on
    add_index :changesets, :committed_on
    add_index :wiki_content_versions, :updated_on
    add_index :messages, :created_on
    add_index :issues, :created_on
    add_index :news, :created_on
    add_index :attachments, :created_on
    add_index :documents, :created_on
    add_index :time_entries, :created_on
  end

  def self.down
    remove_index :journals, :created_on
    remove_index :changesets, :committed_on
    remove_index :wiki_content_versions, :updated_on
    remove_index :messages, :created_on
    remove_index :issues, :created_on
    remove_index :news, :created_on
    remove_index :attachments, :created_on
    remove_index :documents, :created_on
    remove_index :time_entries, :created_on
  end
end
