# frozen_string_literal: true

module Subroutine
  module Outputs
    class UnknownOutputError < StandardError

      def initialize(name)
        super("Unknown output '#{name}'")
      end

    end
  end
end
