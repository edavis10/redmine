class IssueMove < ActiveRecord::Migration[4.2]
  # model removed
  class Permission < ActiveRecord::Base; end

  def self.up
    Permission.create :controller => "projects", :action => "move_issues", :description => "button_move", :sort => 1061, :mail_option => 0, :mail_enabled => 0
  end

  def self.down
    Permission.where("controller=? and action=?", 'projects', 'move_issues').first.destroy
  end
end
