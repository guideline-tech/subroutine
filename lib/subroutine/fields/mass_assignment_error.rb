# frozen_string_literal: true

module Subroutine
  module Fields
    class MassAssignmentError < ::StandardError

      def initialize(field_name)
        super("`#{field_name}` is not mass assignable")
      end

    end
  end
end
