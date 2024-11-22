# frozen_string_literal: true

require 'date'
require 'time'
require 'bigdecimal'
require 'securerandom'
require 'active_support/json'
require 'active_support/core_ext/date_time/acts_like'
require 'active_support/core_ext/date_time/calculations'
require 'active_support/core_ext/object/acts_like'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/time/acts_like'
require 'active_support/core_ext/time/calculations'

module Subroutine
  module TypeCaster

    class TypeCastError < StandardError

      def initialize(message)
        super(message)
      end

    end

    def self.casters
      @casters ||= {}
    end

    def self.register(*names, &block)
      names.each do |n|
        casters[n] = block
      end
    end

    def self.cast(value, options = {})
      type = options[:type]
      return value if value.nil? || type.nil?

      caster = casters[type]
      return value unless caster

      caster.call(value, options)

    rescue StandardError => e
      raise ::Subroutine::TypeCaster::TypeCastError, e.to_s, e.backtrace
    end
  end
end

::Subroutine::TypeCaster.register :number, :float do |value, options = {}|
  next nil if value.blank?

  meth = (options[:methods] || []).detect { |m| value.respond_to?(m) }
  meth ? value.send(meth) : value.to_f
end

::Subroutine::TypeCaster.register :integer, :int, :epoch do |value, _options = {}|
  ::Subroutine::TypeCaster.cast(value, type: :number, methods: [:to_i])
end

::Subroutine::TypeCaster.register :decimal, :big_decimal do |value, _options = {}|
  next nil if value.blank?

  if value.respond_to?(:to_d)
    begin
      next BigDecimal(value.to_s, 0)
    rescue ArgumentError
      next BigDecimal(0)
    end
  end

  ::Subroutine::TypeCaster.cast(value, type: :number, methods: [:to_f])
end

::Subroutine::TypeCaster.register :string, :text do |value, _options = {}|
  String(value)
end

::Subroutine::TypeCaster.register :foreign_key do |value, options = {}|
  next nil if value.blank?

  calculated_type = options[:foreign_key_type].respond_to?(:call)
  calculated_value = calculated_type ? options[:foreign_key_type].call : options[:foreign_key_type]

  next ::Subroutine::TypeCaster.cast(value, type: calculated_value) if calculated_value
  next ::Subroutine::TypeCaster.cast(value, type: :integer) if options[:name] && options[:name].to_s.end_with?("_id")

  value
end

::Subroutine::TypeCaster.register :boolean, :bool do |value, _options = {}|
  !!(String(value) =~ /^(yes|true|1|ok)$/i)
end

::Subroutine::TypeCaster.register :iso_date do |value, _options = {}|
  next nil unless value.present?

  d = nil
  d ||= value if value.is_a?(::Date)
  d ||= value if value.try(:acts_like?, :date)
  d ||= ::Date.parse(String(value))
  d.iso8601
end

::Subroutine::TypeCaster.register :iso_time do |value, _options = {}|
  next nil unless value.present?

  t = nil
  t ||= value if value.is_a?(::Time)
  t ||= value if value.try(:acts_like?, :time)
  t ||= ::Time.parse(String(value))
  t.utc.iso8601(::ActiveSupport::JSON::Encoding.time_precision)
end

::Subroutine::TypeCaster.register :date do |value, _options = {}|
  next nil unless value.present?

  ::Date.parse(String(value))
end

::Subroutine::TypeCaster.register :time, :timestamp, :datetime do |value, options = {}|
  next nil unless value.present?

  value = if value.try(:acts_like?, :time)
    value.to_time
  else
    ::Time.parse(String(value))
  end

  # High precision must be opted into. The original implementation is to set usec:0
  next value if options[:precision] == :high || ::Subroutine.preserve_time_precision?

  value.change(usec: 0)
end

::Subroutine::TypeCaster.register :hash, :object, :hashmap, :dict do |value, _options = {}|
  if value.class.name == 'ActionController::Parameters'
    value = value.to_hash
    value.each_pair do |k, v|
      value[k] = ::Subroutine::TypeCaster.cast(v, type: :hash) if v.class.name == 'ActionController::Parameters'
    end
    next value
  end

  next value if value.is_a?(Hash)
  next {} if value.blank?
  next value.to_hash if value.respond_to?(:to_hash)
  next value.to_h if value.respond_to?(:to_h)
  next ::Hash[value.to_a] if value.respond_to?(:to_a)

  {}
end

::Subroutine::TypeCaster.register :array do |value, options = {}|
  next [] if value.blank?

  out = ::Array.wrap(value)
  out = out.map { |v| ::Subroutine::TypeCaster.cast(v, type: options[:of]) } if options[:of]
  out
end

::Subroutine::TypeCaster.register :file do |value, options = {}|
  next nil if value.blank?

  next value if defined?(::Tempfile) && value.is_a?(::Tempfile)
  next value if value.is_a?(::File)

  value = ::Base64.decode64(value) if options[:base64]

  ::Tempfile.new(SecureRandom.hex).tap do |f|
    f.write(value)
    f.rewind
  end
end
