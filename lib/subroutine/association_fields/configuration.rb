# frozen_string_literal: true

require "subroutine/fields/configuration"
require "subroutine/association_fields/component_configuration"

module Subroutine
  module AssociationFields
    class Configuration < ::Subroutine::Fields::Configuration

      def validate!
        super

        if config[:as] && foreign_key
          raise ArgumentError, ":as and :foreign_key options should not be provided together to an association invocation"
        end
      end

      def required_modules
        super + [::Subroutine::AssociationFields]
      end

      def related_field_names
        out = super
        out << foreign_key_method
        out << foreign_type_method if polymorphic?
        out
      end

      def polymorphic?
        !!config[:polymorphic]
      end

      def as
        config[:as] || field_name
      end

      def class_name
        config[:class_name]&.to_s
      end

      def inferred_class_name
        class_name || as.to_s.camelize
      end

      def foreign_key
        config[:foreign_key]
      end

      def foreign_key_method
        (foreign_key || "#{field_name}_id").to_sym
      end

      def foreign_type_method
        foreign_key_method.to_s.gsub(/_id$/, "_type").to_sym
      end

      def build_foreign_key_field
        build_child_field(foreign_key_method, type: :integer)
      end

      def build_foreign_type_field
        build_child_field(foreign_type_method, type: :string)
      end

      def unscoped?
        !!config[:unscoped]
      end

      def behavior
        :association
      end

      protected

      def build_child_field(name, opts = {})
        ComponentConfiguration.new(name, inheritable_options.merge(opts).merge(association_name: as))
      end

    end
  end
end
