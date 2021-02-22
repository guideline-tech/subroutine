# frozen_string_literal: true

require "active_model"

require "subroutine/failure"
require "subroutine/fields"
require "subroutine/outputs"

module Subroutine
  class Op

    include ::ActiveModel::Validations
    include ::ActiveModel::Validations::Callbacks
    include ::Subroutine::Fields
    include ::Subroutine::Outputs

    class << self

      def failure_class(klass)
        self._failure_class = klass
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

    class_attribute :_error_map
    self._error_map = {}

    def initialize(inputs = {})
      setup_fields(inputs)
      setup_outputs
      yield self if block_given?
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
        validate_outputs!
        self
      else
        raise _failure_class, self
      end
    end

    # the action which should be invoked upon form submission (from the controller)
    def submit
      submit!
      true
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
