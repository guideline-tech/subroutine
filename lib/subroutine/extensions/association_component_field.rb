# frozen_string_literal: true

require "subroutine/field"

module Subroutine
  module Extensions
    class AssociationComponentField < ::Subroutine::Field

      def behavior
        :association_component
      end

      def association_name
        config[:association_name]
      end

    end
  end
end
