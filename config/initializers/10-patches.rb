require 'active_record'

module ActiveRecord
  class Base
    include Redmine::I18n
    # Translate attribute names for validation errors display
    def self.human_attribute_name(attr, *args)
      attr = attr.to_s.sub(/_id$/, '')

      l("field_#{name.underscore.gsub('/', '_')}_#{attr}", :default => ["field_#{attr}".to_sym, attr])
    end
  end

  # Undefines private Kernel#open method to allow using `open` scopes in models.
  # See Defect #11545 (http://www.redmine.org/issues/11545) for details.
  class Base
    class << self
      undef open
    end
  end
  class Relation ; undef open ; end
end

module ActionView
  module Helpers
    module DateHelper
      # distance_of_time_in_words breaks when difference is greater than 30 years
      def distance_of_date_in_words(from_date, to_date = 0, options = {})
        from_date = from_date.to_date if from_date.respond_to?(:to_date)
        to_date = to_date.to_date if to_date.respond_to?(:to_date)
        distance_in_days = (to_date - from_date).abs

        I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
          case distance_in_days
            when 0..60     then locale.t :x_days,             :count => distance_in_days.round
            when 61..720   then locale.t :about_x_months,     :count => (distance_in_days / 30).round
            else                locale.t :over_x_years,       :count => (distance_in_days / 365).floor
          end
        end
      end
    end
  end

  class Resolver
    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      cached(key, [name, prefix, partial], details, locals) do
        if details[:formats] & [:xml, :json]
          details = details.dup
          details[:formats] = details[:formats].dup + [:api]
        end
        find_templates(name, prefix, partial, details)
      end
    end
  end
end

# Do not HTML escape text templates
module ActionView
  class Template
    module Handlers
      class ERB
        def call(template)
          if template.source.encoding_aware?
            # First, convert to BINARY, so in case the encoding is
            # wrong, we can still find an encoding tag
            # (<%# encoding %>) inside the String using a regular
            # expression
            template_source = template.source.dup.force_encoding("BINARY")

            erb = template_source.gsub(ENCODING_TAG, '')
            encoding = $2

            erb.force_encoding valid_encoding(template.source.dup, encoding)

            # Always make sure we return a String in the default_internal
            erb.encode!
          else
            erb = template.source.dup
          end

          self.class.erb_implementation.new(
            erb,
            :trim => (self.class.erb_trim_mode == "-"),
            :escape => template.identifier =~ /\.text/ # only escape HTML templates
          ).src
        end
      end
    end
  end
end

ActionView::Base.field_error_proc = Proc.new{ |html_tag, instance| html_tag || ''.html_safe }

require 'mail'

module DeliveryMethods
  class AsyncSMTP < ::Mail::SMTP
    def deliver!(*args)
      Thread.start do
        super *args
      end
    end
  end

  class AsyncSendmail < ::Mail::Sendmail
    def deliver!(*args)
      Thread.start do
        super *args
      end
    end
  end

  class TmpFile
    def initialize(*args); end

    def deliver!(mail)
      dest_dir = File.join(Rails.root, 'tmp', 'emails')
      Dir.mkdir(dest_dir) unless File.directory?(dest_dir)
      File.open(File.join(dest_dir, mail.message_id.gsub(/[<>]/, '') + '.eml'), 'wb') {|f| f.write(mail.encoded) }
    end
  end
end

ActionMailer::Base.add_delivery_method :async_smtp, DeliveryMethods::AsyncSMTP
ActionMailer::Base.add_delivery_method :async_sendmail, DeliveryMethods::AsyncSendmail
ActionMailer::Base.add_delivery_method :tmp_file, DeliveryMethods::TmpFile

module ActionController
  module MimeResponds
    class Collector
      def api(&block)
        any(:xml, :json, &block)
      end
    end
  end
end

module ActionController
  class Base
    # Displays an explicit message instead of a NoMethodError exception
    # when trying to start Redmine with an old session_store.rb
    # TODO: remove it in a later version
    def self.session=(*args)
      $stderr.puts "Please remove config/initializers/session_store.rb and run `rake generate_secret_token`.\n" +
        "Setting the session secret with ActionController.session= is no longer supported in Rails 3."
      exit 1
    end
  end
end
