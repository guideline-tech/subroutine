require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/object/deep_dup'
require 'active_model'

require "subroutine/failure"
require "subroutine/type_caster"
require "subroutine/filtered_errors"
require "subroutine/output_not_set_error"
require "subroutine/unknown_output_error"

module Subroutine

  class Op

    include ::ActiveModel::Model
    include ::ActiveModel::Validations::Callbacks

    DEFAULT_OUTPUT_OPTIONS = {
      required: true
    }.freeze

    class << self

      ::Subroutine::TypeCaster::TYPES.values.flatten.each do |caster|

        next if method_defined?(caster)

        class_eval <<-EV, __FILE__, __LINE__ + 1
          def #{caster}(*args)
            options = args.extract_options!
            options[:type] = #{caster.inspect}
            args.push(options)
            field(*args)
          end
        EV
      end

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

      def outputs(*names)
        options = names.extract_options!
        names.each do |name|
          self._outputs = self._outputs.merge({
            name.to_sym => DEFAULT_OUTPUT_OPTIONS.merge(options)
          })

          class_eval <<-EV, __FILE__, __LINE__ + 1
            def #{name}
              @outputs[:#{name}]
            end
          EV
        end
      end

      def ignore_error(*field_names)
        field_names.each do |f|
          _ignore_errors(f)
        end
      end
      alias_method :ignore_errors, :ignore_error

      def inputs_from(*ops)
        options = ops.extract_options!
        excepts = Set.new(Array(options.delete(:except)))

        ops.each do |op|
          op._fields.each_pair do |field_name, op_options|
            next if excepts.include? field_name

            if op_options[:association]
              include ::Subroutine::Association unless included_modules.include?(::Subroutine::Association)
              association(field_name, op_options)
            else
              field(field_name, op_options)
            end
          end
        end
      end

      def inherited(child)
        super
        child._fields = self._fields.dup
        child._error_map = self._error_map.dup
        child._error_ignores = self._error_ignores.dup
      end


      def submit!(*args)
        op = new(*args)
        op.submit!

        op
      end

      def submit(*args)
        op = new(*args)
        op.submit
        op
      end

      protected

      def _field(field_name, options = {})
        self._fields[field_name.to_sym] = options

        if options[:aka]
          Array(options[:aka]).each do |as|
            self._error_map[as.to_sym] = field_name.to_sym
          end
        end

        if options[:ignore_errors]
          _ignore_errors(field_name)
        end

        class_eval <<-EV, __FILE__, __LINE__ + 1

          def #{field_name}=(v)
            config = #{field_name}_config
            v = type_caster.cast(v, config[:type])
            @params["#{field_name}"] = v
          end

          def #{field_name}
            @params.has_key?("#{field_name}") ? @params["#{field_name}"] : @defaults["#{field_name}"]
          end

          def #{field_name}_config
            self._fields[:#{field_name}]
          end

        EV

      end

      def _ignore_errors(field_name)
        self._error_ignores[field_name.to_sym] = true
      end

    end


    class_attribute :_outputs
    self._outputs = {}

    class_attribute :_fields
    self._fields = {}

    class_attribute :_error_map
    self._error_map = {}

    class_attribute :_error_ignores
    self._error_ignores = {}

    attr_reader :original_params
    attr_reader :params, :defaults


    def initialize(inputs = {})
      @original_params  = inputs.with_indifferent_access
      @params = sanitize_params(@original_params)
      @defaults = sanitize_defaults
      @outputs = {}
    end

    def errors
      @filtered_errors ||= Subroutine::FilteredErrors.new(super)
    end

    def output(name, value)
      unless _outputs.key?(name.to_sym)
        raise ::Subroutine::UnknownOutputError.new(name)
      end
      @outputs[name.to_sym] = value
    end

    def submit!

      begin
        observe_submission do
          validate_and_perform
        end
      rescue Exception => e
        if e.respond_to?(:record)
          inherit_errors(e.record) unless e.record == self
          raise ::Subroutine::Failure.new(self)
        else
          raise
        end
      end

      if errors.empty?
        _outputs.each_pair do |name, config|
          if config[:required] && !@outputs.key?(name)
            raise ::Subroutine::OutputNotSetError.new(name)
          end
        end

        true
      else
        raise ::Subroutine::Failure.new(self)
      end
    end

    # the action which should be invoked upon form submission (from the controller)
    def submit
      submit!
    rescue Exception => e
      if e.respond_to?(:record)
        inherit_errors(e.record) unless e.record == self
        false
      else
        raise
      end
    end

    def params_with_defaults
      @defaults.merge(@params)
    end

    protected

    def type_caster
      @type_caster ||= ::Subroutine::TypeCaster.new
    end

    # these enable you to 1) add log output or 2) add performance monitoring such as skylight.
    def observe_submission
      yield
    end

    def observe_validation
      yield
    end

    def observe_perform
      yield
    end


    def validate_and_perform
      bool = observe_validation do
        valid?
      end

      return false unless bool

      observe_perform do
        perform
      end
    end

    # implement this in your concrete class.
    def perform
      raise NotImplementedError
    end

    # check if a specific field was provided
    def field_provided?(key)
      @params.has_key?(key)
    end

    # applies the errors in error_object to self
    # returns false so failure cases can end with this invocation
    def inherit_errors(error_object)
      error_object = error_object.errors if error_object.respond_to?(:errors)

      error_object.each do |k,v|

        next if self._error_ignores[k.to_sym]

        if respond_to?("#{k}")
          errors.add(k, v)
        elsif self._error_map[k.to_sym]
          errors.add(self._error_map[k.to_sym], v)
        else
          errors.add(:base, error_object.full_message(k,v))
        end

      end

      false
    end


    # if you want to use strong parameters or something in your form object you can do so here.
    # by default we just slice the inputs to the defined fields
    def sanitize_params(inputs)
      out = {}.with_indifferent_access
      self._fields.each_pair do |field, config|
        if inputs.has_key?(field)
          out[field] = type_caster.cast(inputs[field], config[:type])
        end
      end

      out
    end

    def sanitize_defaults
      defaults = {}.with_indifferent_access

      self._fields.each_pair do |field, config|
        unless config[:default].nil?
          deflt = config[:default]
          if deflt.respond_to?(:call)
            deflt = deflt.call
          elsif deflt.duplicable? # from active_support
            # Some classes of default values need to be duplicated, or the instance field value will end up referencing
            # the class global default value, and potentially modify it.
            deflt = deflt.deep_dup # from active_support
          end
          defaults[field] = type_caster.cast(deflt, config[:type])
        end
      end

      defaults
    end

  end

end
