# frozen_string_literal: true

module Subroutine
  module Auth
    class NotAuthorizedError < ::StandardError

      def initialize(msg = nil)
        msg = I18n.t("errors.#{msg}", default: "Sorry, you are not authorized to perform this action.") if msg.is_a?(Symbol)
        msg ||= I18n.t("errors.unauthorized", default: "Sorry, you are not authorized to perform this action.")
        super msg
      end

      def status
        401
      end

    end
  end
end
