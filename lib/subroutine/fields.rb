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

    included do
      class_attribute :_fields
      self._fields = {}
      attr_reader :original_params
      attr_reader :params, :defaults
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

      def _field(field_name, options = {})
        self._fields = _fields.merge(field_name.to_sym => options)

        class_eval <<-EV, __FILE__, __LINE__ + 1

          def #{field_name}=(v)
            config = #{field_name}_config
            v = ::Subroutine::TypeCaster.cast(v, config)
            @params["#{field_name}"] = v
          end

          def #{field_name}
            @params.has_key?("#{field_name}") ? @params["#{field_name}"] : @defaults["#{field_name}"]
          end

          def #{field_name}_config
            _fields[:#{field_name}]
          end

        EV
      end
    end

    def setup_fields(inputs = {})
      @original_params = inputs.with_indifferent_access
      @params = sanitize_params(@original_params)
      @defaults = sanitize_defaults
    end

    # check if a specific field was provided
    def field_provided?(key)
      return send(:"#{key}_field_provided?") if respond_to?(:"#{key}_field_provided?", true)

      @params.key?(key)
    end

    # if you want to use strong parameters or something in your form object you can do so here.
    # by default we just slice the inputs to the defined fields
    def sanitize_params(inputs)
      out = {}.with_indifferent_access
      _fields.each_pair do |field, config|
        next unless inputs.key?(field)

        begin
          out[field] = ::Subroutine::TypeCaster.cast(inputs[field], config)
        rescue ::Subroutine::TypeCaster::TypeCastError => e
          raise ::Subroutine::TypeCaster::TypeCastError, "Error for field `#{field}`: #{e}"
        end
      end

      out
    end

    def params_with_defaults
      @defaults.merge(@params)
    end

    def sanitize_defaults
      defaults = {}.with_indifferent_access

      _fields.each_pair do |field, config|
        next if config[:default].nil?

        deflt = config[:default]
        if deflt.respond_to?(:call)
          deflt = deflt.call
        elsif deflt.duplicable? # from active_support
          # Some classes of default values need to be duplicated, or the instance field value will end up referencing
          # the class global default value, and potentially modify it.
          deflt = deflt.deep_dup # from active_support
        end
        defaults[field] = ::Subroutine::TypeCaster.cast(deflt, config)
      end

      defaults
    end

  end
end
