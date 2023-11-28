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

    end

    class_attribute :_failure_class
    self._failure_class = Subroutine::Failure

    def initialize(inputs = {})
      setup_fields(inputs)
      setup_outputs
      yield self if block_given?
    end

    def submit!
      observe_entire_submission do
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

    # similar to `observe_submission` but observes the entire `submit!` method
    def observe_entire_submission
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

    def inherit_errors(error_object, prefix: nil)
      error_object = error_object.errors if error_object.respond_to?(:errors) && !error_object.is_a?(ActiveModel::Errors)

      error_object.each do |error|
        field_name = error.attribute
        field_name = "#{prefix}#{field_name}" if prefix
        field_name = field_name.to_sym

        field_config = get_field_config(field_name)
        field_config ||= begin
          kv = field_configurations.find { |_k, config| config[:aka] == field_name }
          kv ? kv.last : nil
        end

        if field_config
          errors.add(field_config.field_name, error.message)
        else
          errors.add(:base, error_object.full_message(field_name, error.message))
        end
      end

      false
    end

  end
end
