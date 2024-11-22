# frozen_string_literal: true

require "subroutine/version"
require "subroutine/fields"
require "subroutine/op"

module Subroutine

  def self.preserve_time_precision=(bool)
    @preserve_time_precision = !!bool
  end

  def self.preserve_time_precision?
    return false unless defined?(@preserve_time_precision)

    !!@preserve_time_precision
  end

end
