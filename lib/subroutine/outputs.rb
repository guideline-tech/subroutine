# frozen_string_literal: true

require "subroutine/outputs/configuration"
require "subroutine/outputs/output_not_set_error"
require "subroutine/outputs/unknown_output_error"
require "subroutine/outputs/invalid_output_type_error"

module Subroutine
  module Outputs

    extend ActiveSupport::Concern

    class LazyExecutor
      def initialize(value)
        @value_block = value
        @executed = false
      end

      def value
        return @value if @executed
        @value = @value_block.respond_to?(:call) ? @value_block.call : @value
        @executed = true
        @value
      end

      def executed?
        @executed
      end
    end

    included do
      class_attribute :output_configurations
      self.output_configurations = {}
    end

    module ClassMethods

      def outputs(*names)
        options = names.extract_options!
        names.each do |name|
          config = ::Subroutine::Outputs::Configuration.new(name, options)
          self.output_configurations = output_configurations.merge(name.to_sym => config)

          class_eval <<-EV, __FILE__, __LINE__ + 1
            def #{name}
              get_output(:#{name})
            end
          EV
        end
      end

    end

    def setup_outputs
      @outputs = {} # don't do with_indifferent_access because it will turn provided objects into with_indifferent_access objects, which may not be the desired behavior
    end

    def outputs
      unless @outputs_executed
        @outputs.each_pair do |key, value|
          @outputs[key] = value.is_a?(LazyExecutor) ? value.value : value
        end
        @outputs_executed = true
      end

      @outputs
    end

    def output(name, value)
      name = name.to_sym
      unless output_configurations.key?(name)
        raise ::Subroutine::Outputs::UnknownOutputError, name
      end

      @outputs[name] = output_configurations[name].lazy? ? LazyExecutor.new(value) : value
    end

    def get_output(name)
      name = name.to_sym
      raise ::Subroutine::Outputs::UnknownOutputError, name unless output_configurations.key?(name)

      output = @outputs[name]
      unless output.is_a?(LazyExecutor)
        output
      else
        # if its not executed, validate the type
        unless output.executed?
          @outputs[name] = output.value
          ensure_output_type_valid!(name)
        end

        @outputs[name]
      end
    end

    def validate_outputs!
      output_configurations.each_pair do |name, config|
        if config.required? && !output_provided?(name)
          raise ::Subroutine::Outputs::OutputNotSetError, name
        end
        unless output_configurations[name].lazy?
          ensure_output_type_valid!(name)
        end
      end
    end

    def ensure_output_type_valid!(name)
      return if valid_output_type?(name)

      name = name.to_sym
      raise ::Subroutine::Outputs::InvalidOutputTypeError.new(
        name: name,
        actual_type: @outputs[name].class,
        expected_type: output_configurations[name][:type]
      )
    end

    def output_provided?(name)
      name = name.to_sym

      @outputs.key?(name)
    end

    def valid_output_type?(name)
      name = name.to_sym

      return true unless output_configurations.key?(name)

      output_configuration = output_configurations[name]
      return true unless output_configuration[:type]
      return true if !output_configuration.required? && @outputs[name].nil?

      @outputs[name].is_a?(output_configuration[:type])
    end
  end
end
