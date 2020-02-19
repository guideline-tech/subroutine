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

    def self.allowed_input_classes
      @allowed_input_classes ||= begin
        out = [Hash]
        out << ActionController::Parameters if action_controller_params_loaded?
        out
      end
    end

    def self.action_controller_params_loaded?
      defined?(::ActionController::Parameters)
    end

    included do
      class_attribute :field_configurations
      self.field_configurations = {}

      class_attribute :field_groups
      self.field_groups = Set.new
    end

    module ClassMethods

      def field(field_name, options = {})
        config = ::Subroutine::Fields::Configuration.from(field_name, options)
        config.validate!

        self.field_configurations = field_configurations.merge(field_name.to_sym => config)

        ensure_field_accessors(config)

        config.groups.each do |group_name|
          ensure_group_accessors(group_name)
        end

        config
      end
      alias input field

      def fields_from(*things)
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

            field(field_name, config.merge(options))
          end
        end
      end
      alias inputs_from fields_from

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

      def ensure_group_accessors(group_name)
        group_name = group_name.to_sym
        return if field_groups.include?(group_name)

        self.field_groups |= [group_name]

        class_eval <<-EV, __FILE__, __LINE__ + 1
          def #{group_name}_params
            param_groups[:#{group_name}]
          end

          def #{group_name}_default_params
            group_field_names = fields_in_group(:#{group_name}).keys
            all_default_params.slice(*group_field_names)
          end
          alias #{group_name}_defaults #{group_name}_default_params

          def #{group_name}_params_with_default_params
            #{group_name}_default_params.merge(param_groups[:#{group_name}])
          end
          alias #{group_name}_params_with_defaults #{group_name}_params_with_default_params

          def without_#{group_name}_params
            all_params.except(*#{group_name}_params.keys)
          end
        EV
      end

      def ensure_field_accessors(config)
        if config.field_writer?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            try(:silence_redefinition_of_method, :#{config.field_name}=)
            def #{config.field_name}=(v)
              set_field(:#{config.field_name}, v)
            end
          EV
        end

        if config.field_reader?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            try(:silence_redefinition_of_method, :#{config.field_name})
            def #{config.field_name}
              get_field(:#{config.field_name})
            end
          EV
        end
      end

    end

    def setup_fields(inputs = {})
      if ::Subroutine::Fields.action_controller_params_loaded? && inputs.is_a?(::ActionController::Parameters)
        inputs = inputs.to_unsafe_h
      end
      @provided_fields = {}.with_indifferent_access
      param_groups[:original] = inputs.with_indifferent_access
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

    def all_params
      get_param_group(:all)
    end
    alias params all_params

    def all_default_params
      get_param_group(:default)
    end
    alias defaults all_default_params

    def all_params_with_defaults
      all_default_params.merge(all_params)
    end
    alias params_with_defaults all_params_with_defaults

    def ungrouped_defaults
      default_params.slice(*ungrouped_fields.keys)
    end

    def ungrouped_params_with_defaults
      ungrouped_defaults.merge(ungrouped_params)
    end

    def get_field_config(field_name)
      self.class.get_field_config(field_name)
    end

    # check if a specific field was provided
    def field_provided?(key)
      !!@provided_fields[key]
    end

    def get_field(name)
      field_provided?(name) ? all_params[name] : all_default_params[name]
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

    def fields_in_group(group_name)
      self.class.fields_in_group(group_name)
    end

    def ungrouped_fields
      fields.select { |f| f.groups.empty? }.each_with_object({}) do |f, h|
        h[f.name] = f
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
        end

        next unless config.has_default?

        value = attempt_cast(config.get_default, config) do |e|
          "Error for default `#{field}`: #{e}"
        end

        param_groups[:default][field_name] = value
      end
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
