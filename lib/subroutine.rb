# frozen_string_literal: true

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
