require 'date'
require 'time'
require 'bigdecimal'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/array/wrap'

module Subroutine
  module TypeCaster

    def casters
      @casters ||= {}
    end
    module_function :casters

    def register(*names, &block)
      names.each do |n|
        casters[n] = block
      end
    end
    module_function :register

    def cast(value, type, *args)
      return value if value.nil? || type.nil?

      caster = casters[type]
      caster ? caster.call(value, *args) : value
    end
    module_function :cast

  end
end

Subroutine::TypeCaster.register :number do |value, *meths|
  next nil if value.blank?
  meth = meths.detect{|m| value.respond_to?(m) }
  meth ? value.send(meth) : value.to_f
end

Subroutine::TypeCaster.register :integer, :int, :epoch do |value|
  Subroutine::TypeCaster.cast(value, :number, :to_i)
end

Subroutine::TypeCaster.register :decimal, :big_decimal do |value|
  Subroutine::TypeCaster.cast(value, :number, :to_d, :to_f)
end

Subroutine::TypeCaster.register :string, :text do |value|
  String(value)
end

Subroutine::TypeCaster.register :boolean, :bool do |value|
  !!(String(value) =~ /^(yes|true|1|ok)$/)
end

Subroutine::TypeCaster.register :iso_date do |value|
  next nil unless value.present?
  d = nil
  d ||= value if value.is_a?(::Date)
  d ||= value if value.try(:acts_like?, :date)
  d ||= ::Date.parse(String(value))
  d.iso8601
end

Subroutine::TypeCaster.register :iso_time do |value|
  next nil unless value.present?
  t = nil
  t ||= value if value.is_a?(::Time)
  t ||= value if value.try(:acts_like?, :time)
  t ||= ::Time.parse(String(value))
  t.utc.iso8601
end

Subroutine::TypeCaster.register :date do |value|
  next nil unless value.present?
  ::Date.parse(String(value))
end

Subroutine::TypeCaster.register :time, :timestamp, :datetime do |value|
  next nil unless value.present?
  ::Time.parse(String(value))
end

Subroutine::TypeCaster.register :hash, :object, :hashmap, :dict do |value|
  if value.class.name == 'ActionController::Parameters'
    value = value.to_hash
    value.each_pair { |k, v| value[k] = Subroutine::TypeCaster.cast(v, :hash) if v.class.name == 'ActionController::Parameters' }
    next value
  end

  next value if value.is_a?(Hash)
  next {} if value.blank?
  next value.to_hash if value.respond_to?(:to_hash)
  next value.to_h if value.respond_to?(:to_h)
  next ::Hash[value.to_a] if value.respond_to?(:to_a)
  {}
end

Subroutine::TypeCaster.register :array do |value|
  next [] if value.blank?
  ::Array.wrap(value)
end
