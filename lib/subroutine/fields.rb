# frozen_string_literal: true

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
      class_attribute :fields_by_group, default: Hash.new { |h, k| h[k] = Set.new }
    end

    module ClassMethods

      VALIDATOR_KEYS = ::ActiveModel::Validations.constants.filter_map do |constant|
        next unless constant.to_s.end_with?("Validator")

        constant.to_s.gsub(/Validator$/, "").underscore.to_sym
      end.freeze

      def field(field_name, options = {})
        config = ::Subroutine::Fields::Configuration.from(field_name, options)
        config.validate!

        self.field_configurations = field_configurations.merge(field_name.to_sym => config)

        ensure_field_accessors(config)

        if config.groups.any?
          new_fields_by_group = self.fields_by_group.deep_dup

          config.groups.each do |group_name|
            new_fields_by_group[group_name] << config.field_name
            ensure_group_accessors(group_name)
          end

          self.fields_by_group = new_fields_by_group
        end

        add_validations_from_options(field_name, options)

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
            return #{group_name}_params_with_defaults if include_defaults_in_params?

            #{group_name}_provided_params
          end

          silence_redefinition_of_method def #{group_name}_provided_params
            get_param_group(:#{group_name}_provided)
          end

          silence_redefinition_of_method def #{group_name}_default_params
            get_param_group(:#{group_name}_default)
          end
          alias #{group_name}_defaults #{group_name}_default_params

          silence_redefinition_of_method def #{group_name}_params_with_default_params
            param_cache[:#{group_name}_provided_and_default] ||= begin
              #{group_name}_default_params.merge(#{group_name}_provided_params)
            end
          end
          alias #{group_name}_params_with_defaults #{group_name}_params_with_default_params

          silence_redefinition_of_method def without_#{group_name}_params
            param_cache[:without_#{group_name}] ||= begin
              all_params.except(*#{group_name}_params.keys)
            end
          end
        EV
      end

      def ensure_field_accessors(config)
        if config.field_writer?
          class_eval <<-EV, __FILE__, __LINE__ + 1
            silence_redefinition_of_method def #{config.field_name}=(v)
              set_field(:#{config.field_name}, v, group_type: :provided)
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

      def add_validations_from_options(field_name, options)
        options.each do |key, value|
          next unless VALIDATOR_KEYS.include?(key)

          # Format the validation depending on whether the value is a hash or simple value
          validation_str = value.is_a?(Hash) ? value.inspect : value

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            validates :#{field_name}, #{key}: #{validation_str}
          RUBY
        end
      end

    end

    def setup_fields(inputs = {})
      if ::Subroutine::Fields.action_controller_params_loaded? && inputs.is_a?(::ActionController::Parameters)
        inputs = inputs.to_unsafe_h if inputs.respond_to?(:to_unsafe_h)
      end
      inputs.each_pair do |k, v|
        set_param_group_value(:original, k, v)
      end
      mass_assign_initial_params
    end

    def include_defaults_in_params?
      self.class.include_defaults_in_params?
    end

    def param_cache
      @param_cache ||= {}
    end

    def param_groups
      @param_groups ||= Hash.new { |h, k| h[k] = {}.with_indifferent_access }
    end

    def get_param_group(name)
      name = name.to_sym
      return param_groups[name] if param_groups.key?(name)

      param_groups[name] = yield if block_given?
      param_groups[name]
    end

    def set_param_group_value(name, key, value)
      config = get_field_config(key)
      group = get_param_group(name)

      if config&.bypass_indifferent_assignment?
        group.regular_writer(group.send(:convert_key, key), value)
      else
        group[key.to_sym] = value
      end
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
      return all_params_with_default_params if include_defaults_in_params?

      all_provided_params
    end
    alias params all_params

    def all_params_with_default_params
      param_cache[:provided_and_default] ||= all_default_params.merge(all_provided_params)
    end
    alias all_params_with_defaults all_params_with_default_params
    alias params_with_defaults all_params_with_defaults

    def get_field_config(field_name)
      self.class.get_field_config(field_name)
    end

    def field_provided?(key)
      all_provided_params.key?(key)
    end

    def get_field(name)
      all_params_with_default_params[name]
    end

    def set_field(name, value, group_type: :provided)
      config = get_field_config(name)
      value = attempt_cast(value, config) do |e|
        "Error during assignment of field `#{name}`: #{e}"
      end

      set_param_group_value(group_type, config.field_name, value)

      config.groups.each do |group_name|
        set_param_group_value(:"#{group_name}_#{group_type}", config.field_name, value)
      end

      param_cache.clear

      value
    end

    def clear_field(name)
      param_cache.clear
      param_groups.each_pair do |key, group|
        next if key == :original
        next if key == :default

        group.delete(name)
      end
    end

    protected

    def mass_assign_initial_params
      field_configurations.each_pair do |field_name, config|
        if !config.mass_assignable? && original_params.key?(field_name)
          raise ::Subroutine::Fields::MassAssignmentError, field_name
        end

        if original_params.key?(field_name)
          set_field(field_name, original_params[field_name], group_type: :provided)
        end

        next unless config.has_default?

        set_field(field_name, config.get_default, group_type: :default)
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
