# frozen_string_literal: true

require "subroutine/fields/configuration"

module Subroutine
  module AssociationFields
    class ComponentConfiguration < ::Subroutine::Fields::Configuration

      def behavior
        :association_component
      end

      def association_name
        config[:association_name]
      end

    end
  end
end
