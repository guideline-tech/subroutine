# frozen_string_literal: true

require "subroutine/field"

module Subroutine
  module Extensions
    class AssociationComponentField < ::Subroutine::Field

      def association_component?
        true
      end

      def association_name
        config[:association_name]
      end

    end
  end
end
