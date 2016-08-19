require 'date'
require 'time'
require 'bigdecimal'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/array/wrap'

module Subroutine
  class TypeCaster


    TYPES = {
      :integer => [:int, :integer, :epoch],
      :number => [:number, :float],
      :decimal => [:decimal, :big_decimal],
      :string => [:string, :text],
      :boolean => [:bool, :boolean],
      :iso_date => [:iso_date],
      :iso_time => [:iso_time],
      :date => [:date],
      :time => [:time, :timestamp],
      :hash => [:object, :hashmap, :dict],
      :array => [:array]
    }


    def cast(value, type)
      return value if value.nil? || type.nil?

      case type.to_sym
      when *TYPES[:integer]
        cast_number(value).try(:to_i)
      when *TYPES[:number]
        cast_number(value).try(:to_f)
      when *TYPES[:decimal]
        d = cast_number(value)
        d ? BigDecimal(d.to_s) : nil
      when *TYPES[:string]
        cast_string(value)
      when *TYPES[:boolean]
        cast_boolean(value)
      when *TYPES[:iso_date]
        t = cast_iso_time(value)
        t ? t.split('T')[0] : t
      when *TYPES[:date]
        cast_date(value).try(:to_date)
      when *TYPES[:iso_time]
        cast_iso_time(value)
      when *TYPES[:time]
        cast_time(value)
      when *TYPES[:hash]
        cast_hash(value)
      when *TYPES[:array]
        cast_array(value)
      else
        value
      end
    end

    protected

    def cast_number(value)
      val = cast_string(value).strip
      return nil if val.blank?
      val
    end

    def cast_string(value)
      String(value)
    end

    def cast_boolean(value)
      !!(cast_string(value) =~ /^(yes|true|1|ok)$/)
    end

    def cast_time(value)
      return nil unless value.present?
      ::Time.parse(cast_string(value))
    end

    def cast_date(value)
      return nil unless value.present?
      ::Date.parse(cast_string(value))
    end

    def cast_iso_time(value)
      return nil unless value.present?
      t = nil
      t ||= value if value.is_a?(::Time)
      t ||= value if value.try(:acts_like?, :time)
      t ||= ::Time.parse(cast_string(value))
      t.utc.iso8601
    end

    def cast_iso_date(value)
      return nil unless value.present?
      d = nil
      d ||= value if value.is_a?(::Date)
      d ||= value if value.try(:acts_like?, :date)
      d ||= ::Date.parse(cast_string(value))
      d.iso8601
    end

    def cast_hash(value)
      _cast_hash(value).try(:stringify_keys)
    end

    def _cast_hash(value)
      return _cast_action_controller_query_params(value) if is_action_controller_query_params?(value)
      return value if value.is_a?(Hash)
      return {} if value.blank?
      return value.to_hash if value.respond_to?(:to_hash)
      return value.to_h if value.respond_to?(:to_h)
      return ::Hash[value.to_a] if value.respond_to?(:to_a)
      {}
    end

    def _cast_action_controller_query_params(value)
      value = value.to_hash
      value.each_pair{|k,v| value[k] = _cast_action_controller_query_params(v) if is_action_controller_query_params?(v) }
      value
    end

    def is_action_controller_query_params?(value)
      value.class.name == "ActionController::Parameters"
    end

    def cast_array(value)
      return [] if value.blank?
      ::Array.wrap(value)
    end

  end
end
