# frozen_string_literal: true

require "active_model"

require "subroutine/fields"
require "subroutine/failure"
require "subroutine/output_not_set_error"
require "subroutine/unknown_output_error"

module Subroutine
  class Op

    include ::ActiveModel::Validations
    include ::ActiveModel::Validations::Callbacks
    include ::Subroutine::Fields

    DEFAULT_OUTPUT_OPTIONS = {
      required: true,
    }.freeze

    class << self

      def failure_class(klass)
        self._failure_class = klass
      end

      def outputs(*names)
        options = names.extract_options!
        names.each do |name|
          self._outputs = _outputs.merge(name.to_sym => DEFAULT_OUTPUT_OPTIONS.merge(options))

          class_eval <<-EV, __FILE__, __LINE__ + 1
            def #{name}
              @outputs[:#{name}]
            end
          EV
        end
      end

      def submit!(*args)
        raise ArgumentError, "Blocks cannot be provided to `submit!`" if block_given?

        op = new(*args)
        op.submit!

        op
      end

      def submit(*args)
        raise ArgumentError, "Blocks cannot be provided to `submit`." if block_given?

        op = new(*args)
        op.submit
        op
      end

      protected

      def field(field_name, options = {})
        result = super(field_name, options)

        if options[:aka]
          Array(options[:aka]).each do |as|
            self._error_map = _error_map.merge(as.to_sym => field_name.to_sym)
          end
        end

        result
      end

    end

    class_attribute :_failure_class
    self._failure_class = Subroutine::Failure

    class_attribute :_outputs
    self._outputs = {}

    class_attribute :_error_map
    self._error_map = {}

    def initialize(inputs = {})
      setup_fields(inputs)
      @outputs = {}
      yield self if block_given?
    end

    def output(name, value)
      unless _outputs.key?(name.to_sym)
        raise ::Subroutine::UnknownOutputError, name
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
          new_e = _failure_class.new(self)
          raise new_e, new_e.message, e.backtrace
        else
          raise
        end
      end

      if errors.empty?
        _outputs.each_pair do |name, config|
          if config[:required] && !@outputs.key?(name)
            raise ::Subroutine::OutputNotSetError, name
          end
        end

        true
      else
        raise _failure_class, self
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

    protected

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
      bool = observe_validation { valid? }
      return false unless bool

      observe_perform { perform }
    end

    # implement this in your concrete class.
    def perform
      raise NotImplementedError
    end

    # applies the errors in error_object to self
    # returns false so failure cases can end with this invocation
    def inherit_errors(error_object)
      error_object = error_object.errors if error_object.respond_to?(:errors)

      error_object.each do |k, v|
        if respond_to?(k)
          errors.add(k, v)
        elsif _error_map[k.to_sym]
          errors.add(_error_map[k.to_sym], v)
        else
          errors.add(:base, error_object.full_message(k, v))
        end
      end

      false
    end

  end
end
