module Redmine
  module Info
    class << self
      def app_name; 'Redmine' end
      def url; 'http://www.redmine.org/' end
      def help_url; 'http://www.redmine.org/guide' end
      def versioned_name; "#{app_name} #{Redmine::VERSION}" end

      def environment
        s = "Environment:\n"
        s << [
          ["Redmine version", Redmine::VERSION],
          ["Ruby version", "#{RUBY_VERSION} (#{RUBY_PLATFORM})"],
          ["Rails version", Rails::VERSION::STRING],
          ["Environment", Rails.env],
          ["Database adapter", ActiveRecord::Base.connection.adapter_name]
        ].map {|info| "  %-40s %s" % info}.join("\n")
        s << "\nRedmine plugins:\n"

        plugins = Redmine::Plugin.all
        if plugins.any?
          s << plugins.map {|plugin| "  %-40s %s" % [plugin.id.to_s, plugin.version.to_s]}.join("\n")
        else
          s << "  no plugin installed"
        end
      end
    end
  end
end
