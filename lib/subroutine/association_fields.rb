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
            string config.foreign_type_method, config.build_foreign_type_field
          else
            class_eval <<-EV, __FILE__, __LINE__ + 1
              def #{config.foreign_type_method}
                #{config.inferred_class_name.inspect}
              end
            EV
          end

          integer config.foreign_key_method, config.build_foreign_key_field

          field_without_association(config.as, config)
        else
          field_without_association(field_name, options)
        end
      end

    end

    def set_field_with_association(field_name, value, opts = {})
      config = get_field_config(field_name)

      if config&.behavior == :association
        maybe_raise_on_type_mismatch!(config, value)
        set_field(config.foreign_type_method, value&.class&.name, opts) if config.polymorphic?
        set_field(config.foreign_key_method, value&.id, opts)
      elsif config&.behavior == :association_component
        clear_field_without_association(config.association_name)
      end

      set_field_without_association(field_name, value, opts)
    end

    def get_field_with_association(field_name)
      config = get_field_config(field_name)

      if config&.behavior == :association
        stored_result = get_field_without_association(field_name)
        return stored_result unless stored_result.nil?

        fk = send(config.foreign_key_method)
        type = send(config.foreign_type_method)

        result = fetch_association_instance(type, fk, config.unscoped?)
        set_field_without_association(field_name, result)
        result
      else
        get_field_without_association(field_name)
      end
    end

    def clear_field_with_association(field_name)
      config = get_field_config(field_name)

      if config&.behavior == :association
        clear_field(config.foreign_type_method) if config.polymorphic?
        clear_field(config.foreign_key_method)
      end

      clear_field_without_association(field_name)
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

    def fetch_association_instance(_type, _fk, _unscoped = false)
      return nil unless _type && _fk

      klass = _type
      klass = klass.classify.constantize if klass.is_a?(String)

      return nil unless klass

      scope = klass.all
      scope = scope.unscoped if _unscoped

      scope.find(_fk)
    end

    def maybe_raise_on_type_mismatch!(config, record)
      return if config.polymorphic?
      return if record.nil?

      klass = config.inferred_class_name.constantize

      return if record.class <= klass || record.class >= klass

      message = "#{klass}(##{klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"

      errors.add(:base, message)
      raise Subroutine::AssociationFields::AssociationTypeMismatchError, self
    end

  end
end
