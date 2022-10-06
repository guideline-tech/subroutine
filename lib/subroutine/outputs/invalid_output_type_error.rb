# frozen_string_literal: true

module Subroutine
  module Outputs
    class InvalidOutputTypeError < StandardError

      def initialize(name:, expected_type:, actual_type:)
        super("Invalid output type for '#{name}' expected #{expected_type} but got #{actual_type}")
      end

    end
  end
end
