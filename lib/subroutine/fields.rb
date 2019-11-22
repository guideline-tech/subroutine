# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/deep_dup"

require "subroutine/type_caster"
require "subroutine/association"

module Subroutine
  module Fields

    extend ActiveSupport::Concern

    PROTECTED_FIELD_IDENTIFIERS = %i[defaults all].freeze

    included do
      class_attribute :_fields
      self._fields = {}
      attr_reader :original_params
    end

    module ClassMethods
      # fields can be provided in the following way:
      # field :field1, :field2
      # field :field3, :field4, default: 'my default'
      def field(*fields)
        options = fields.extract_options!

        fields.each do |f|
          _field(f, options)
        end
      end
      alias_method :fields, :field

      def inputs_from(*things)
        options = things.extract_options!
        excepts = options.key?(:except) ? Array(options.delete(:except)) : nil
        onlys = options.key?(:only) ? Array(options.delete(:only)) : nil

        things.each do |thing|
          thing._fields.each_pair do |field_name, opts|
            next if excepts && excepts.include?(field_name)
            next if onlys && !onlys.include?(field_name)

            if opts[:association]
              include ::Subroutine::Association unless included_modules.include?(::Subroutine::Association)
              association(field_name, opts)
            else
              field(field_name, opts)
            end
          end
        end
      end
      alias_method :fields_from, :inputs_from

      def fields_in_group(group_name)
        group_name = group_name.to_s
        _fields.each_with_object({}) do |(field_name, config), h|
          h[field_name] = config if config[:group].include?(group_name)
        end
      end

      def respond_to_missing?(method_name, *args, &block)
        ::Subroutine::TypeCaster.casters.key?(method_name.to_sym) || super
      end

      def method_missing(method_name, *args, &block)
        caster = ::Subroutine::TypeCaster.casters[method_name.to_sym]
        if caster
          options = args.extract_options!
          options[:type] = method_name.to_sym
          args.push(options)
          field(*args, &block)
        else
          super
        end
      end

      protected

      def _field(field_name, field_writer: true, field_reader: true, **options)

        unless options[:group].nil?
          options[:group] = Array(options[:group]).map(&:to_s)
          options[:group].each do |group|
            next unless PROTECTED_FIELD_IDENTIFIERS.include?(group.to_sym)
            raise ArgumentError, "Cannot assign a field to protected group `#{group}`. Protected groups are: #{PROTECTED_FIELD_IDENTIFIERS.join(", ")}"
            _group(group)
          end
        end


        self._fields = _fields.merge(field_name.to_sym => options)

        if field_writer
          class_eval <<-EV, __FILE__, __LINE__ + 1
            try(:silence_redefinition_of_method, :#{field_name}=)
            def #{field_name}=(v)
              set_field(:#{field_name}, v)
            end
          EV
        end

        if field_reader
          class_eval <<-EV, __FILE__, __LINE__ + 1
            try(:silence_redefinition_of_method, :#{field_name})
            def #{field_name}
              get_field(:#{field_name})
            end
          EV
        end

        class_eval <<-EV, __FILE__, __LINE__ + 1
          try(:silence_redefinition_of_method, :#{field_name}_config)
          def #{field_name}_config
            _fields[:#{field_name}]
          end
        EV
      end
    end

    def _group(group_name)
      class_eval <<-EV, __FILE__, __LINE__ + 1
        try(:silence_redefinition_of_method, :#{group_name}_params)
        def #{group_name}_params
          @param_groups[:#{group_name}]
        end
      EV
    end

    def setup_fields(inputs = {})
      @original_params = inputs.with_indifferent_access
      @fields_provided = {}.with_indifferent_access
      @param_groups = Hash.new{|h, k| h[k] = {}.with_indifferent_access }
      @param_groups[:defaults] = build_defaults
      @param_groups[:all] = build_params(@original_params, @param_groups[:defaults])
    end

    def params
      @param_groups[:all]
    end

    alias_method :all_params, :params

    def defaults
      @param_groups[:defaults]
    end
    alias_method :default_params, :defaults

    # check if a specific field was provided
    def field_provided?(key)
      return send(:"#{key}_field_provided?") if respond_to?(:"#{key}_field_provided?", true)

      !!@fields_provided[key]
    end

    # if you want to use strong parameters or something in your form object you can do so here.
    # by default we just slice the inputs to the defined fields
    def build_params(inputs, defaults)
      out = {}.with_indifferent_access

      _fields.each_pair do |field, config|

        if config[:mass_assignable] == false && inputs.key?(field)
          raise ArgumentError, "`#{field}` is not mass assignable"
        end

        if inputs.key?(field)
          @fields_provided[field] = true
          out[field] = attempt_cast(inputs[field], config) do |e|
            "Error for field `#{field}`: #{e}"
          end
        elsif defaults.key?(field)
          out[field] =  defaults[field]
        else
          next
        end
      end

      out
    end

    def build_defaults
      @defaults = {}.with_indifferent_access

      _fields.each_pair do |field, config|
        next unless config.key?(:default)

        deflt = config[:default]
        if deflt.respond_to?(:call)
          deflt = deflt.call
        elsif deflt.try(:duplicable?) # from active_support
          # Some classes of default values need to be duplicated, or the instance field value will end up referencing
          # the class global default value, and potentially modify it.
          deflt = deflt.deep_dup # from active_support
        end

        @defaults[field.to_s] = attempt_cast(deflt, config) do |e|
          "Error for default `#{field}`: #{e}"
        end
      end

      @defaults
    end

    def attempt_cast(value, config)
      ::Subroutine::TypeCaster.cast(value, config)
      rescue ::Subroutine::TypeCaster::TypeCastError => e
      message = block_given? ? yield(e) : e.to_s
      raise ::Subroutine::TypeCaster::TypeCastError, message, e.backtrace
    end

    def get_field(name)
      params[name]
    end

    def set_field(name, value)
      config = _fields[name]
      @fields_provided[name] = true
      value = attempt_cast(value, config) do |e|
        "Error during assignment of field `#{name}`: \#{e}"
      end
      each_param_group_for_field(name) do |h|
        h[name] = value
      end
      value
    end

    def each_param_group_for_field(name)
      config = _fields[name]
      yield params

      Array(config[:groups]).each do |group_name|
        yield @param_groups[group_name]
      end

      Array(config[:group]).each do |group_name|
        yield @param_groups[group_name]
      end
    end

  end
end
