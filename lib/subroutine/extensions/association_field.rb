# frozen_string_literal: true

require "subroutine/field"
require "subroutine/extensions/association_component_field"

module Subroutine
  module Extensions
    class AssociationField < ::Subroutine::Field

      def validate!
        super

        if as && foreign_key
          raise ArgumentError, ":as and :foreign_key options should not be provided together to an association invocation"
        end
      end

      def required_modules
        super + [::Subroutine::Extensions::Association]
      end

      def polymorphic?
        !!config[:polymorphic]
      end

      def as
        config[:as] || field_name
      end

      def class_name
        config[:class_name]
      end

      def inferred_class_name
        class_name || as.to_s.camelize
      end

      def foreign_key
        config[:foreign_key]
      end

      def foreign_key_method
        foreign_key || "#{field_name}_id"
      end

      def foreign_type_method
        foreign_key_method.gsub(/_id$/, "_type")
      end

      def build_foreign_key_field
        build_child_field(foreign_key_method)
      end

      def build_foreign_type_field
        build_child_field(foreign_type_method)
      end

      def unscoped?
        !!config[:unscoped]
      end

      def association?
        true
      end

      protected

      def build_child_field(name)
        AssociationComponentField.new(name, inheritable_options.merge(association_name: as))
      end

    end
  end
end
