# frozen_string_literal: true

require "delegate"

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

      DEFAULT_OPTIONS = { required: true }.freeze

      attr_reader :output_name

      def initialize(output_name, config)
        @output_name = output_name
        super(DEFAULT_OPTIONS.merge(config))
      end

      alias config __getobj__

      def required?
        case config[:required]
        when Proc
          config[:required].call
        else
          !!config[:required]
        end
      end

      def inspect
        "#<#{self.class}:#{object_id} name=#{output_name} config=#{config.inspect}>"
      end

    end
  end
end
