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

      def foreign_type
        (config[:foreign_type] || config[:class_name])&.to_s
      end
      alias class_name foreign_type

      def inferred_foreign_type
        foreign_type || as.to_s.camelize
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

      def find_by
        (config[:find_by] || :id).to_sym
      end

      def build_foreign_key_field
        build_child_field(foreign_key_method, type: :foreign_key, foreign_key_type: determine_foreign_key_type)
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
        child_opts = inheritable_options
        child_opts.merge!(opts)
        child_opts[:association_name] = as
        ComponentConfiguration.new(name, child_opts)
      end

      def determine_foreign_key_type
        return config[:foreign_key_type] if config[:foreign_key_type]

        # TODO: Make this logic work for polymorphic associations.
        return if polymorphic?

        klass = inferred_foreign_type&.constantize
        if klass && klass.respond_to?(:type_for_attribute)
          return unless klass.table_exists?
          
          case klass.type_for_attribute(find_by)&.type&.to_sym
          when :string
            :string
          else
            :integer
          end
        end
      end

    end
  end
end
