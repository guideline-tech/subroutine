# frozen_string_literal: true

require "active_model"
require "active_support"
require "active_support/concern"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/string/inflections"
require "delegate"

require "subroutine/version"
require "subroutine/fields"
require "subroutine/op"

require "logger"

module Subroutine

  def self.logger
    @logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  # Used by polymorphic association fields to resolve the class name to a ruby class
  def self.constantize_polymorphic_class_name(class_name)
    return @constantize_polymorphic_class_name.call(class_name) if defined?(@constantize_polymorphic_class_name)

    class_name.camelize.constantize
  end

  # When you need to customize how a polymorphic class name is resolved, you can set this callable/lambda/proc
  def self.constantize_polymorphic_class_name=(callable)
    @constantize_polymorphic_class_name = callable
  end

  def self.include_defaults_in_params=(bool)
    @include_defaults_in_params = !!bool
  end

  def self.include_defaults_in_params?
    return !!@include_defaults_in_params if defined?(@instance_defaults_in_params)

    false
  end

  def self.field_redefinition_behavior
    @field_redefinition_behavior ||= :warn
  end

  def self.field_redefinition_behavior=(symbol)
    symbol = symbol.to_sym
    possible = %i[error warn ignore]
    raise ArgumentError, "#{symbol} must be one of #{possible.inspect}" unless possible.include?(symbol)

    @field_redefinition_behavior = symbol
  end

  def self.inheritable_field_options=(opts)
    @inheritable_field_options = opts.map(&:to_sym)
  end

  def self.inheritable_field_options
    @inheritable_field_options ||= %i[mass_assignable field_reader field_writer groups aka]
  end

  def self.preserve_time_precision=(bool)
    @preserve_time_precision = !!bool
  end

  def self.preserve_time_precision?
    return !!@preserve_time_precision if defined?(@preserve_time_precision)

    false
  end

end
