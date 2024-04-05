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
      class_attribute :include_defaults_in_params, instance_accessor: false, instance_predicate: false
      class_attribute :field_configurations, default: {}
      class_attribute :field_groups, default: Hash.new { |h, k| h[k] = Set.new }
    end

    module ClassMethods

      def field(field_name, options = {})
        config = ::Subroutine::Fields::Configuration.from(field_name, options)
        config.validate!

        self.field_configurations = field_configurations.merge(field_name.to_sym => config)

        ensure_field_accessors(config)

        if config.groups.any?
          new_groups = self.field_groups.deep_dup
          config.groups.each do |group_name|
            new_groups[group_name] << config.field_name
            ensure_group_accessors(group_name)
          end
          self.field_groups = new_groups
        end

        config
      end
      alias input field

      def fields_from(*things)
        options = things.extract_options!
        excepts = options.key?(:except) ? Array(options.delete(:except)) : nil
        onlys = options.key?(:only) ? Array(options.delete(:only)) : nil

        things.each do |thing|
          local_excepts = excepts.map { |field| thing.get_field_config(field)&.related_field_names }.flatten.compact.uniq if excepts
          local_onlys = onlys.map { |field| thing.get_field_config(field)&.related_field_names }.flatten.compact.uniq if onlys

          thing.field_configurations.each_pair do |field_name, config|
            next if local_excepts&.include?(field_name)
            next if local_onlys && !local_onlys.include?(field_name)

            config.required_modules.each do |mod|
              include mod unless included_modules.include?(mod)
            end

            field(field_name, config.merge(options))
          end
        end
      end
      alias inputs_from fields_from

      def get_field_config(field_name)
        field_configurations[field_name.to_sym]
      end

      def include_defaults_in_params?
        return include_defaults_in_params unless include_defaults_in_params.nil?

        Subroutine.include_defaults_in_params?
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
        class_eval <<-EV, __FILE__, __LINE__ + 1
          silence_redefinition_of_method def #{group_name}_params
            include_defaults_in_params? ?
              #{group_name}_params_with_default_params :
              #{group_name}_provided_params
          end

          silence_redefinition_of_method def #{group_name}_provided_params
            param_cache[:#{group_name}_provided] ||= begin
              group_field_names = field_groups[:#{group_name}]
              provided_params.slice(*group_field_names)
            end
          end

          silence_redefinition_of_method def #{group_name}_default_params
            param_cache[:#{group_name}_default] ||= begin
              group_field_names = field_groups[:#{group_name}]
              all_default_params.slice(*group_field_names)
            end
          end
          alias #{group_name}_defaults #{group_name}_default_params

          silence_redefinition_of_method def #{group_name}_params_with_default_params
            param_cache[:#{group_name}_provided_and_default] ||= #{group_name}_default_params.merge(#{group_name}_provided_params)
          end
          alias #{group_name}_params_with_defaults #{group_name}_params_with_default_params

          silence_redefinition_of_method def without_#{group_name}_params
            param_cache[:without_#{group_name}] ||= all_params.except(*#{group_name}_params.keys)
          end
        EV
      end

      def ensure_field_accessors(config)
        if config.field_writer?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            silence_redefinition_of_method def #{config.field_name}=(v)
              set_field(:#{config.field_name}, v, provided: true)
            end
          EV
        end

        if config.field_reader?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            silence_redefinition_of_method def #{config.field_name}
              get_field(:#{config.field_name})
            end
          EV
        end
      end

    end

    def setup_fields(inputs = {})
      if ::Subroutine::Fields.action_controller_params_loaded? && inputs.is_a?(::ActionController::Parameters)
        inputs = inputs.to_unsafe_h if inputs.respond_to?(:to_unsafe_h)
      end
      param_groups[:original].merge!(inputs)
      mass_assign_initial_params
    end

    def include_defaults_in_params?
      self.class.include_defaults_in_params?
    end

    def param_groups
      @param_groups ||= Hash.new { |h, k| h[k] = {}.with_indifferent_access }
    end

    def param_cache
      @param_cache ||= Hash.new
    end

    def get_param_group(name)
      param_groups[name.to_sym]
    end

    def original_params
      get_param_group(:original)
    end

    def all_provided_params
      get_param_group(:provided)
    end
    alias provided_params all_provided_params

    def all_default_params
      get_param_group(:default)
    end
    alias defaults all_default_params
    alias default_params all_default_params

    def all_params
      if include_defaults_in_params?
        all_params_with_defaults
      else
        provided_params
      end
    end
    alias params all_params

    def all_params_with_defaults
      param_cache[:provided_and_default] ||= all_default_params.merge(all_provided_params)
    end
    alias params_with_defaults all_params_with_defaults


    def get_field_config(field_name)
      self.class.get_field_config(field_name)
    end

    def field_provided?(key)
      all_provided_params.key?(key)
    end

    def get_field(name)
      field_provided?(name) ? provided_params[name] : all_default_params[name]
    end

    def set_field(name, value, provided: true)
      config = get_field_config(name)
      value = attempt_cast(value, config) do |e|
        "Error during assignment of field `#{name}`: #{e}"
      end

      param_cache.clear
      param_groups[:provided][name] = value if provided
      param_groups[:default][name] = value unless provided
      value
    end

    def clear_field(name)
      param_groups[:provided].delete(name)
    end

    protected

    def mass_assign_initial_params
      field_configurations.each_pair do |field_name, config|
        if !config.mass_assignable? && original_params.key?(field_name)
          raise ::Subroutine::Fields::MassAssignmentError, field_name
        end

        if original_params.key?(field_name)
          set_field(field_name, original_params[field_name], provided: true)
        end

        next unless config.has_default?

        set_field(field_name, config.get_default, provided: false)
      end
    end

    def attempt_cast(value, config)
      ::Subroutine::TypeCaster.cast(value, config)
    rescue ::Subroutine::TypeCaster::TypeCastError => e
      message = block_given? ? yield(e) : e.to_s
      raise ::Subroutine::TypeCaster::TypeCastError, message, e.backtrace
    end

  end
end
