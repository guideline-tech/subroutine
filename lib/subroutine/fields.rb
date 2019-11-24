# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/deep_dup"

require "subroutine/type_caster"
require "subroutine/fields/configuration"
require "subroutine/fields/mass_assignment_error"

module Subroutine
  module Fields

    extend ActiveSupport::Concern

    included do
      class_attribute :field_configurations
      self.field_configurations = {}
    end

    module ClassMethods

      def field(field_name, options = {})
        config = ::Subroutine::Fields::Configuration.from(field_name, options)
        config.validate!

        config.groups.each do |group_name|
          _group(group_name)
        end

        self.field_configurations = field_configurations.merge(field_name.to_sym => config)

        if config.field_writer?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            try(:silence_redefinition_of_method, :#{field_name}=)
            def #{field_name}=(v)
              set_field(:#{field_name}, v)
            end
          EV
        end

        if config.field_reader?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            try(:silence_redefinition_of_method, :#{field_name})
            def #{field_name}
              get_field(:#{field_name})
            end
          EV
        end
      end
      alias input field

      def inputs_from(*things)
        options = things.extract_options!
        excepts = options.key?(:except) ? Array(options.delete(:except)) : nil
        onlys = options.key?(:only) ? Array(options.delete(:only)) : nil

        things.each do |thing|
          thing.field_configurations.each_pair do |field_name, config|
            next if excepts&.include?(field_name)
            next if onlys && !onlys.include?(field_name)

            config.required_modules.each do |mod|
              include mod unless included_modules.include?(mod)
            end

            field(field_name, config)
          end
        end
      end
      alias fields_from inputs_from

      def fields_in_group(group_name)
        field_configurations.each_with_object({}) do |(field_name, config), h|
          next unless config.in_group?(group_name)

          h[field_name] = config
        end
      end

      def get_field_config(field_name)
        field_configurations[field_name.to_sym]
      end

      def respond_to_missing?(method_name, *args, &block)
        ::Subroutine::TypeCaster.casters.key?(method_name.to_sym) || super
      end

      def method_missing(method_name, *args, &block)
        caster = ::Subroutine::TypeCaster.casters[method_name.to_sym]
        if caster
          field_name, options = args
          options ||= {}
          options[:type] = method_name.to_sym
          field(field_name, options)
        else
          super
        end
      end

      protected

      def _group(group_name)
        class_eval <<-EV, __FILE__, __LINE__ + 1
          try(:silence_redefinition_of_method, :#{group_name}_params)
          def #{group_name}_params
            param_groups[:#{group_name}]
          end

          try(:silence_redefinition_of_method, :without_#{group_name}_params)
          def without_#{group_name}_params
            all_params.except(*#{group_name}_params.keys)
          end
        EV
      end

    end

    def setup_fields(inputs = {})
      @provided_fields = {}.with_indifferent_access
      param_groups[:original] = inputs.with_indifferent_access
      param_groups[:default] = build_defaults
      mass_assign_initial_params
    end

    def param_groups
      @param_groups ||= Hash.new { |h, k| h[k] = {}.with_indifferent_access }
    end

    def get_param_group(name)
      param_groups[name.to_sym]
    end

    def original_params
      get_param_group(:original)
    end

    def ungrouped_params
      get_param_group(:ungrouped)
    end
    alias params ungrouped_params

    def all_params
      get_param_group(:all)
    end

    def defaults
      get_param_group(:default)
    end
    alias default_params defaults

    def get_field_config(field_name)
      self.class.get_field_config(field_name)
    end

    # check if a specific field was provided
    def field_provided?(key)
      !!@provided_fields[key]
    end

    def get_field(name)
      all_params[name]
    end

    def set_field(name, value, track_provided: true)
      config = get_field_config(name)
      @provided_fields[name] = true if track_provided
      value = attempt_cast(value, config) do |e|
        "Error during assignment of field `#{name}`: #{e}"
      end
      each_param_group_for_field(name) do |h|
        h[name] = value
      end
      value
    end

    def clear_field(name)
      each_param_group_for_field(name) do |h|
        h.delete(name)
      end
    end

    protected

    def mass_assign_initial_params
      field_configurations.each_pair do |field_name, config|
        if !config.mass_assignable? && original_params.key?(field_name)
          raise ::Subroutine::Fields::MassAssignmentError, field_name
        end

        if original_params.key?(field_name)
          set_field(field_name, original_params[field_name])
        elsif defaults.key?(field_name)
          set_field(field_name, defaults[field_name], track_provided: false)
        end
      end
    end

    def build_defaults
      out = {}.with_indifferent_access

      field_configurations.each_pair do |field, config|
        next unless config.key?(:default)

        deflt = config[:default]
        if deflt.respond_to?(:call)
          deflt = deflt.call
        elsif deflt.try(:duplicable?) # from active_support
          # Some classes of default values need to be duplicated, or the instance field value will end up referencing
          # the class global default value, and potentially modify it.
          deflt = deflt.deep_dup # from active_support
        end

        out[field.to_s] = attempt_cast(deflt, config) do |e|
          "Error for default `#{field}`: #{e}"
        end
      end

      out
    end

    def attempt_cast(value, config)
      ::Subroutine::TypeCaster.cast(value, config)
    rescue ::Subroutine::TypeCaster::TypeCastError => e
      message = block_given? ? yield(e) : e.to_s
      raise ::Subroutine::TypeCaster::TypeCastError, message, e.backtrace
    end

    def each_param_group_for_field(name)
      config = get_field_config(name)
      yield all_params

      if config.groups.empty?
        yield ungrouped_params
      else
        config.groups.each do |group_name|
          yield param_groups[group_name]
        end
      end
    end

  end
end
