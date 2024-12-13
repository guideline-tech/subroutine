# frozen_string_literal: true

module Subroutine
  module Outputs
    class Configuration < ::SimpleDelegator

      def self.from(field_name, options)
        case options
        when Subroutine::Outputs::Configuration
          options.class.new(field_name, options)
        else
          new(field_name, options)
        end
      end

      DEFAULT_OPTIONS = {
        required: true,
        lazy: false
      }.freeze

      attr_reader :output_name

      def initialize(output_name, config)
        @output_name = output_name
        super(DEFAULT_OPTIONS.merge(config))
      end

      alias config __getobj__

      def required?
        !!config[:required]
      end

      def lazy?
        !!config[:lazy]
      end

      def inspect
        "#<#{self.class}:#{object_id} name=#{output_name} config=#{config.inspect}>"
      end

    end
  end
end
