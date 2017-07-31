class ChangeUserPreferencesHideMailDefaultToTrue < ActiveRecord::Migration[4.2]
  def self.up
    change_column :user_preferences, :hide_mail, :boolean, :default => true
  end

  def self.down
    change_column :user_preferences, :hide_mail, :boolean, :default => false
  end
end
