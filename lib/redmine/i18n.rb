# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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
  module I18n
    def self.included(base)
      base.extend Redmine::I18n
    end

    def l(*args)
      case args.size
      when 1
        ::I18n.t(*args)
      when 2
        if args.last.is_a?(Hash)
          ::I18n.t(*args)
        elsif args.last.is_a?(String)
          ::I18n.t(args.first, :value => args.last)
        else
          ::I18n.t(args.first, :count => args.last)
        end
      else
        raise "Translation string with multiple values: #{args.first}"
      end
    end

    def l_or_humanize(s, options={})
      k = "#{options[:prefix]}#{s}".to_sym
      ::I18n.t(k, :default => s.to_s.humanize)
    end

    def l_hours(hours)
      hours = hours.to_f
      l((hours < 2.0 ? :label_f_hour : :label_f_hour_plural), :value => ("%.2f" % hours.to_f))
    end

    def ll(lang, str, value=nil)
      ::I18n.t(str.to_s, :value => value, :locale => lang.to_s.gsub(%r{(.+)\-(.+)$}) { "#{$1}-#{$2.upcase}" })
    end

    def format_date(date)
      return nil unless date
      options = {}
      options[:format] = Setting.date_format unless Setting.date_format.blank?
      options[:locale] = User.current.language unless User.current.language.blank?
      ::I18n.l(date.to_date, options)
    end

    def format_time(time, include_date = true)
      return nil unless time
      options = {}
      options[:format] = (Setting.time_format.blank? ? :time : Setting.time_format)
      options[:locale] = User.current.language unless User.current.language.blank?
      time = time.to_time if time.is_a?(String)
      zone = User.current.time_zone
      local = zone ? time.in_time_zone(zone) : (time.utc? ? time.localtime : time)
      (include_date ? "#{format_date(local)} " : "") + ::I18n.l(local, options)
    end

    def day_name(day)
      ::I18n.t('date.day_names')[day % 7]
    end

    def day_letter(day)
      ::I18n.t('date.abbr_day_names')[day % 7].first
    end

    def month_name(month)
      ::I18n.t('date.month_names')[month]
    end

    def valid_languages
      ::I18n.available_locales
    end

    # Returns an array of languages names and code sorted by names, example:
    # [["Deutsch", "de"], ["English", "en"] ...]
    #
    # The result is cached to prevent from loading all translations files.
    def languages_options
      ActionController::Base.cache_store.fetch "i18n/languages_options" do
        valid_languages.map {|lang| [ll(lang.to_s, :general_lang_name), lang.to_s]}.sort {|x,y| x.first <=> y.first }
      end      
    end

    def find_language(lang)
      @@languages_lookup = valid_languages.inject({}) {|k, v| k[v.to_s.downcase] = v; k }
      @@languages_lookup[lang.to_s.downcase]
    end

    def set_language_if_valid(lang)
      if l = find_language(lang)
        ::I18n.locale = l
      end
    end

    def current_language
      ::I18n.locale
    end

    # Custom backend based on I18n::Backend::Simple with the following changes:
    # * lazy loading of translation files
    # * available_locales are determined by looking at translation file names
    class Backend
      (class << self; self; end).class_eval { public :include }

      module Implementation
        include ::I18n::Backend::Base

        # Stores translations for the given locale in memory.
        # This uses a deep merge for the translations hash, so existing
        # translations will be overwritten by new ones only at the deepest
        # level of the hash.
        def store_translations(locale, data, options = {})
          locale = locale.to_sym
          translations[locale] ||= {}
          data = data.deep_symbolize_keys
          translations[locale].deep_merge!(data)
        end

        # Get available locales from the translations filenames
        def available_locales
          @available_locales ||= ::I18n.load_path.map {|path| File.basename(path, '.*')}.uniq.sort.map(&:to_sym)
        end

        # Clean up translations
        def reload!
          @translations = nil
          @available_locales = nil
          super
        end

        protected

        def init_translations(locale)
          locale = locale.to_s
          paths = ::I18n.load_path.select {|path| File.basename(path, '.*') == locale.to_s}
          load_translations(paths)
          translations[locale] ||= {}
        end

        def translations
          @translations ||= {}
        end

        # Looks up a translation from the translations hash. Returns nil if
        # eiher key is nil, or locale, scope or key do not exist as a key in the
        # nested translations hash. Splits keys or scopes containing dots
        # into multiple keys, i.e. <tt>currency.format</tt> is regarded the same as
        # <tt>%w(currency format)</tt>.
        def lookup(locale, key, scope = [], options = {})
          init_translations(locale) unless translations.key?(locale)
          keys = ::I18n.normalize_keys(locale, key, scope, options[:separator])

          keys.inject(translations) do |result, _key|
            _key = _key.to_sym
            return nil unless result.is_a?(Hash) && result.has_key?(_key)
            result = result[_key]
            result = resolve(locale, _key, result, options.merge(:scope => nil)) if result.is_a?(Symbol)
            result
          end
        end
      end

      include Implementation
      # Adds fallback to default locale for untranslated strings
      include ::I18n::Backend::Fallbacks
    end
  end
end
