# frozen_string_literal: true

require "active_model"
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

module Subroutine

  def self.include_defaults_in_params=(bool)
    @include_defaults_in_params = !!bool
  end

  def self.include_defaults_in_params?
    return !!@include_defaults_in_params if defined?(@instance_defaults_in_params)

    false
  end

end
