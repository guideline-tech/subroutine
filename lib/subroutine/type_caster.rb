# frozen_string_literal: true

require 'date'
require 'time'
require 'bigdecimal'
require 'securerandom'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/array/wrap'

module Subroutine
  # Registers named types for explicitly casting Op inputs to known types.
  #
  # It is important to note that TypeCaster does not implicitlyvalidate types
  # and Op validations are run against the cast values, not the original inputs.
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

# Cast inputs to a number. By default, it will be cast to a float using #to_f.
# If a `methods` option is passed, the specified methods will be iterated over
# until the first method that the input responds to, and the number will be cast
# using that method.
#
# @return [Number] - The cast value
::Subroutine::TypeCaster.register :number, :float do |value, options = {}|
  next nil if value.blank?

  meth = (options[:methods] || []).detect { |m| value.respond_to?(m) }
  meth ? value.send(meth) : value.to_f
end

# Cast inputs to an Integer
#
# @ return [Integer] - The cast value
::Subroutine::TypeCaster.register :integer, :int, :epoch do |value, _options = {}|
  ::Subroutine::TypeCaster.cast(value, type: :number, methods: [:to_i])
end

# Attempt to cast input to a BigDecimal value. If #to_d is not defined on the receiver,
# casts to a float instead.
#
# @ return [BigDecimal, Float]
::Subroutine::TypeCaster.register :decimal, :big_decimal do |value, _options = {}|
  ::Subroutine::TypeCaster.cast(value, type: :number, methods: [:to_d, :to_f])
end

# Cast input to a string.
#
# @ return [String]
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

# Casts inputs to a String and then compares them with a set of true values. If
# the String-cast version does not match an input, a false value is returned.
# The set of truthy strings is:
#   - true
#   - yes
#   - 1
#   - ok
#
# @return [Boolean]
::Subroutine::TypeCaster.register :boolean, :bool do |value, _options = {}|
  !!(String(value) =~ /^(yes|true|1|ok)$/)
end

# Casts input to an ISO-8601 String representation of the date. The input can be a Date,
# Date-like, or a String representation of a date.
#
# @return [String] - ISO-8601 representation of the input.
::Subroutine::TypeCaster.register :iso_date do |value, _options = {}|
  next nil unless value.present?

  d = nil
  d ||= value if value.is_a?(::Date)
  d ||= value if value.try(:acts_like?, :date)
  d ||= ::Date.parse(String(value))
  d.iso8601
end

# Casts input to a UTC, ISO-8601 String representation of the time. The input can be a Time,
# Time-like, or a String representation of the time.
#
# @return [String] - ISO-8601 representation of the input
::Subroutine::TypeCaster.register :iso_time do |value, _options = {}|
  next nil unless value.present?

  t = nil
  t ||= value if value.is_a?(::Time)
  t ||= value if value.try(:acts_like?, :time)
  t ||= ::Time.parse(String(value))
  t.utc.iso8601
end

# Casts input to a Date object. The input must be able to be Stringified into a parseable
# date string.
#
# @return [Date]
::Subroutine::TypeCaster.register :date do |value, _options = {}|
  next nil unless value.present?

  ::Date.parse(String(value))
end

# Casts input to a Time object. The input must be able to be Stringified into a parseable
# time string.
#
# @return [Date]
::Subroutine::TypeCaster.register :time, :timestamp, :datetime do |value, _options = {}|
  next nil unless value.present?

  ::Time.parse(String(value))
end

# Casts input to a Hash. If the input reponds to #to_hash, its internal implentation will
# be used. ActionController::Parameters objects will be recursively cast hash values of that type.
#
# @return [Date]
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
