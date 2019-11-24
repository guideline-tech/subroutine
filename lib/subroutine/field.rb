# frozen_string_literal: true

require "delegate"

module Subroutine
  class Field < ::SimpleDelegator

    PROTECTED_GROUP_IDENTIFIERS = %i[all original default].freeze
    INHERITABLE_OPTIONS = %i[mass_assignable field_reader field_writer].freeze

    def self.from(field_name, options)
      case options
      when Subroutine::Field
        options.class.new(field_name, options)
      else
        new(field_name, options)
      end
    end

    attr_reader :field_name

    def initialize(field_name, options)
      @field_name = field_name
      config = sanitize_options(options)
      super(config)
      validate!
    end

    alias config __getobj__

    def required_modules
      []
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

    def parent_field
      config[:parent_field]
    end

    def groups
      config[:groups]
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
      opts[:groups] = Array(groups).map(&:to_sym)
      opts.delete(:group)
      opts
    end

  end
end
