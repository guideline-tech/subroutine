require 'active_support/core_ext/hash/indifferent_access'
require 'active_model'

require "subroutine/failure"
require "subroutine/type_caster"
require "subroutine/filtered_errors"

module Subroutine

  class Op

    include ::ActiveModel::Model
    include ::ActiveModel::Validations::Callbacks

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

      def ignore_error(*field_names)
        field_names.each do |f|
          _ignore_errors(f)
        end
      end
      alias_method :ignore_errors, :ignore_error

      def inputs_from(*ops)
        ops.each do |op|
          op._fields.each_pair do |field_name, options|
            field(field_name, options)
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
            @#{field_name} = type_caster.cast(v, config[:type])
          end

          def #{field_name}
            return @#{field_name} if defined?(@#{field_name})
            config = #{field_name}_config
            deflt = config[:default]
            deflt = deflt.call if deflt.respond_to?(:call)
            type_caster.cast(deflt, config[:type])
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


    class_attribute :_fields
    self._fields = {}

    class_attribute :_error_map
    self._error_map = {}

    class_attribute :_error_ignores
    self._error_ignores = {}

    attr_reader :original_params
    attr_reader :params


    def initialize(inputs = {})
      @original_params  = inputs.with_indifferent_access
      @params           = {}
    end

    def errors
      @filtered_errors ||= Subroutine::FilteredErrors.new(super)
    end

    def submit!
      unless submit
        raise ::Subroutine::Failure.new(self)
      end
      true
    end

    # the action which should be invoked upon form submission (from the controller)
    def submit
      observe_submission do
        @params = filter_params(@original_params)

        set_accessors(@params)

        validate_and_perform
      end

    rescue Exception => e

      if e.respond_to?(:record)
        inherit_errors(e.record) unless e.record == self
        false
      else
        raise e
      end
    end

    protected

    # ensure that our type caster has the opportunity to cast each key
    def params
      out = {}
      @params.keys.each do |k|
        out[k] = send(k)
      end
      out
    end

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
    def filter_params(inputs)
      inputs.slice(*_fields.keys)
    end


    def set_accessors(inputs)
      inputs.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end

  end

end
