# frozen_string_literal: true

require "delegate"
require "active_support/concern"
require "subroutine/association_fields/configuration"
require "subroutine/association_fields/association_type_mismatch_error"

module Subroutine
  module AssociationFields

    extend ActiveSupport::Concern

    included do
      class << self

        alias_method :field_without_association, :field
        alias_method :field, :field_with_association

      end

      attr_reader :association_cache

      alias_method :setup_fields_without_association, :setup_fields
      alias_method :setup_fields, :setup_fields_with_association

      alias_method :set_field_without_association, :set_field
      alias_method :set_field, :set_field_with_association

      alias_method :get_field_without_association, :get_field
      alias_method :get_field, :get_field_with_association

      alias_method :clear_field_without_association, :clear_field
      alias_method :clear_field, :clear_field_with_association

      alias_method :field_provided_without_association?, :field_provided?
      alias_method :field_provided?, :field_provided_with_association?
    end

    module ClassMethods

      def association(field_name, opts = {})
        field(field_name, opts.merge(type: :association))
      end

      # association :user
      #  - user_id
      #  - user_type => "User"

      # association :user, polymorphic: true
      #  - user_id
      #  - user_type
      #  - user => polymorphic_lookup(user_type, user_id)

      # association :inbound_user_request, as: :request
      #  - inbound_user_request_id
      #  - inbound_user_request_type => "InboundUserRequest"
      #  - request => polymorphic_lookup(inbound_user_request_type, inbound_user_request_id)

      # association :inbound_user_request, foreign_key: :request_id
      #  - request_id
      #  - request_type
      #  - inbound_user_request => polymorphic_lookup(request_type, request_id)

      # Other options:
      # - unscoped => set true if the record should be looked up via Type.unscoped

      def field_with_association(field_name, options = {})
        if options[:type]&.to_sym == :association
          config = ::Subroutine::AssociationFields::Configuration.new(field_name, options)

          if config.polymorphic?
            field config.foreign_type_method, config.build_foreign_type_field
          else
            class_eval <<-EV, __FILE__, __LINE__ + 1
              try(:silence_redefinition_of_method, :#{config.foreign_type_method})
              def #{config.foreign_type_method}
                #{config.inferred_foreign_type.inspect}
              end
            EV
          end

          field config.foreign_key_method, config.build_foreign_key_field

          field_without_association(config.as, config)
        else
          field_without_association(field_name, options)
        end
      end

    end

    def setup_fields_with_association(*args)
      @association_cache = {}
      setup_fields_without_association(*args)
    end

    def params_with_associations
      association_fields = field_configurations.select { |_name, config| config.behavior == :association }
      return params if association_fields.empty?

      excepts = []
      association_fields.each_pair do |_name, config|
        excepts |= config.related_field_names
      end

      out = params.except(*excepts)
      association_fields.each_pair do |field_name, config|
        next unless field_provided?(field_name)

        out[field_name] = config.field_reader? ? send(field_name) : get_field(field_name)
      end

      out
    end

    def set_field_with_association(field_name, value, opts = {})
      config = get_field_config(field_name)

      if config&.behavior == :association
        maybe_raise_on_association_type_mismatch!(config, value)
        set_field(config.foreign_type_method, value&.class&.name, opts) if config.polymorphic?
        set_field(config.foreign_key_method, value&.send(config.find_by), opts)
        association_cache[config.field_name] = value
      else
        if config&.behavior == :association_component
          clear_field_without_association(config.association_name)
        end

        set_field_without_association(field_name, value, opts)
      end
    end

    def get_field_with_association(field_name)
      config = get_field_config(field_name)

      if config&.behavior == :association
        stored_result = association_cache[config.field_name]
        return stored_result unless stored_result.nil?

        result = fetch_association_instance(config)
        association_cache[config.field_name] = result
      else
        get_field_without_association(field_name)
      end
    end

    def clear_field_with_association(field_name)
      config = get_field_config(field_name)

      if config&.behavior == :association
        clear_field(config.foreign_type_method) if config.polymorphic?
        clear_field(config.foreign_key_method)
        association_cache.delete(config.field_name)
      else
        clear_field_without_association(field_name)
      end
    end

    def field_provided_with_association?(field_name)
      config = get_field_config(field_name)

      if config&.behavior == :association
        provided = true
        provided &&= field_provided?(config.foreign_type_method) if config.polymorphic?
        provided &&= field_provided?(config.foreign_key_method)
        provided
      elsif config&.behavior == :association_component
        field_provided_without_association?(field_name) ||
          field_provided_without_association?(config.association_name)
      else
        field_provided_without_association?(field_name)
      end
    end

    def fetch_association_instance(config)
      klass =
        if config.field_reader?
          config.polymorphic? ? send(config.foreign_type_method) : config.inferred_foreign_type
        else
          get_field(config.foreign_type_method)
        end

      klass = klass.classify.constantize if klass.is_a?(String)
      return nil unless klass

      foreign_key = config.foreign_key_method
      value = send(foreign_key)
      return nil unless value

      scope = klass.all
      scope = scope.unscoped if config.unscoped?

      scope.find_by!(config.find_by => value)
    end

    def maybe_raise_on_association_type_mismatch!(config, record)
      return if config.polymorphic?
      return if record.nil?

      klass = config.inferred_foreign_type.constantize

      return if record.class <= klass || record.class >= klass

      message = "#{klass}(##{klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"

      errors.add(:base, message)
      raise Subroutine::AssociationFields::AssociationTypeMismatchError, self
    end

  end
end
