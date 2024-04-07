# frozen_string_literal: true

module Subroutine
  module Fields
    class Configuration < ::SimpleDelegator

      PROTECTED_GROUP_IDENTIFIERS = %i[all original default].freeze
      INHERITABLE_OPTIONS = %i[mass_assignable field_reader field_writer groups aka].freeze
      NO_GROUPS = [].freeze

      def self.from(field_name, options)
        case options
        when Subroutine::Fields::Configuration
          options.class.new(field_name, options)
        else
          new(field_name, options)
        end
      end

      attr_reader :field_name

      def initialize(field_name, options)
        @field_name = field_name.to_sym
        config = sanitize_options(options)
        super(config)
        validate!
      end

      alias config __getobj__

      def merge(options = {})
        self.class.new(field_name, config.merge(options))
      end

      def required_modules
        []
      end

      def related_field_names
        [field_name]
      end

      def behavior
        nil
      end

      def has_default?
        config.key?(:default)
      end

      def get_default
        value = config[:default]
        if value.respond_to?(:call)
          value = value.call
        elsif value.try(:duplicable?) # from active_support
          # Some classes of default values need to be duplicated, or the instance field value will end up referencing
          # the class global default value, and potentially modify it.
          value = value.deep_dup # from active_support
        end
        value
      end

      def inheritable_options
        config.slice(*INHERITABLE_OPTIONS)
      end

      def mass_assignable?
        config[:mass_assignable] != false
      end

      def field_writer?
        config[:field_writer] != false
      end

      def field_reader?
        config[:field_reader] != false
      end

      def groups
        config[:groups] || NO_GROUPS
      end

      def in_group?(group_name)
        groups.include?(group_name.to_sym)
      end

      def validate!
        PROTECTED_GROUP_IDENTIFIERS.each do |group_name|
          next unless in_group?(group_name)

          raise ArgumentError, "Cannot assign a field to protected group `#{group}`. Protected groups are: #{PROTECTED_GROUP_IDENTIFIERS.join(", ")}"
        end
      end

      def sanitize_options(options)
        opts = (options || {}).to_h.dup
        groups = opts[:group] || opts[:groups]
        groups = nil if groups == false
        opts[:groups] = Array(groups).map(&:to_sym).presence
        opts.delete(:group)
        opts[:aka] = opts[:aka].to_sym if opts[:aka]
        opts[:name] = field_name
        opts
      end

      def inspect
        "#<#{self.class}:#{object_id} name=#{field_name} config=#{config.inspect}>"
      end

    end
  end
end
