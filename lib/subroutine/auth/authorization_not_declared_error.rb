# frozen_string_literal: true

module Subroutine
  module Auth
    class AuthorizationNotDeclaredError < ::StandardError

      def initialize(msg = nil)
        super(msg || "Authorization management has not been declared on this class")
      end

    end
  end
end
