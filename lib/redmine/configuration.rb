# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Configuration

    # Configuration default values
    @defaults = {
      'email_delivery' => nil
    }

    @config = nil

    class << self
      # Loads the Redmine configuration file
      # Valid options:
      # * <tt>:file</tt>: the configuration file to load (default: config/configuration.yml)
      # * <tt>:env</tt>: the environment to load the configuration for (default: Rails.env)
      def load(options={})
        filename = options[:file] || File.join(Rails.root, 'config', 'configuration.yml')
        env = options[:env] || Rails.env

        @config = @defaults.dup

        load_deprecated_email_configuration(env)
        if File.file?(filename)
          @config.merge!(load_from_yaml(filename, env))
        end

        # Compatibility mode for those who copy email.yml over configuration.yml
        %w(delivery_method smtp_settings sendmail_settings).each do |key|
          if value = @config.delete(key)
            @config['email_delivery'] ||= {}
            @config['email_delivery'][key] = value
          end
        end

        if @config['email_delivery']
          ActionMailer::Base.perform_deliveries = true
          @config['email_delivery'].each do |k, v|
            v.symbolize_keys! if v.respond_to?(:symbolize_keys!)
            ActionMailer::Base.send("#{k}=", v)
          end
        end

        @config
      end

      # Returns a configuration setting
      def [](name)
        load unless @config
        @config[name]
      end

      # Yields a block with the specified hash configuration settings
      def with(settings)
        settings.stringify_keys!
        load unless @config
        was = settings.keys.inject({}) {|h,v| h[v] = @config[v]; h}
        @config.merge! settings
        yield if block_given?
        @config.merge! was
      end

      private

      def load_from_yaml(filename, env)
        yaml = nil
        begin
          yaml = YAML::load_file(filename)
        rescue ArgumentError
          $stderr.puts "Your Redmine configuration file located at #{filename} is not a valid YAML file and could not be loaded."
          exit 1
        end
        conf = {}
        if yaml.is_a?(Hash)
          if yaml['default']
            conf.merge!(yaml['default'])
          end
          if yaml[env]
            conf.merge!(yaml[env])
          end
        else
          $stderr.puts "Your Redmine configuration file located at #{filename} is not a valid Redmine configuration file."
          exit 1
        end
        conf
      end

      def load_deprecated_email_configuration(env)
        deprecated_email_conf = File.join(Rails.root, 'config', 'email.yml')
        if File.file?(deprecated_email_conf)
          warn "Storing outgoing emails configuration in config/email.yml is deprecated. You should now store it in config/configuration.yml using the email_delivery setting."
          @config.merge!({'email_delivery' => load_from_yaml(deprecated_email_conf, env)})
        end
      end
    end
  end
end
