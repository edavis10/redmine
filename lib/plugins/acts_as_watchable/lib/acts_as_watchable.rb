# ActsAsWatchable
module Redmine
  module Acts
    module Watchable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_watchable(options = {})
          return if self.included_modules.include?(Redmine::Acts::Watchable::InstanceMethods)
          class_eval do
            has_many :watchers, :as => :watchable, :dependent => :delete_all
            has_many :watcher_users, :through => :watchers, :source => :user, :validate => false

            scope :watched_by, lambda { |user_id|
              joins(:watchers).
              where("#{Watcher.table_name}.user_id = ?", user_id)
            }
          end
          send :include, Redmine::Acts::Watchable::InstanceMethods
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        # Returns an array of users that are proposed as watchers
        def addable_watcher_users
          users = self.project.users.sort - self.watcher_users
          if respond_to?(:visible?)
            users.reject! {|user| !visible?(user)}
          end
          users
        end

        # Adds user as a watcher
        def add_watcher(user)
          # Rails does not reset the has_many :through association
          watcher_users.reset
          self.watchers << Watcher.new(:user => user)
        end

        # Removes user from the watchers list
        def remove_watcher(user)
          return nil unless user && user.is_a?(User)
          # Rails does not reset the has_many :through association
          watcher_users.reset
          watchers.where(:user_id => user.id).delete_all
        end

        # Adds/removes watcher
        def set_watcher(user, watching=true)
          watching ? add_watcher(user) : remove_watcher(user)
        end

        # Overrides watcher_user_ids= to make user_ids uniq
        def watcher_user_ids=(user_ids)
          if user_ids.is_a?(Array)
            user_ids = user_ids.uniq
          end
          super user_ids
        end

        # Returns true if object is watched by +user+
        def watched_by?(user)
          !!(user && self.watcher_user_ids.detect {|uid| uid == user.id })
        end

        def notified_watchers
          notified = watcher_users.active.to_a
          notified.reject! {|user| user.mail.blank? || user.mail_notification == 'none'}
          if respond_to?(:visible?)
            notified.reject! {|user| !visible?(user)}
          end
          notified
        end

        # Returns an array of watchers' email addresses
        def watcher_recipients
          notified_watchers.collect(&:mail)
        end

        module ClassMethods; end
      end
    end
  end
end
