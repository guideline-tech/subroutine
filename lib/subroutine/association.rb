# frozen_string_literal: true
require "active_support/concern"

module Subroutine
  module Association
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method :field_without_associations, :field
        alias_method :field, :field_with_associations
      end

      alias_method :setup_fields_without_association, :setup_fields
      alias_method :setup_fields, :setup_fields_with_association
    end

    module ClassMethods
      def field_with_associations(*args)
        opts = args.extract_options!
        if opts[:association]
          args.each do |arg|
            association(arg, opts)
          end
        else
          field_without_associations(*args, opts)
        end
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

      def association(field, options = {})
        if options[:as] && options[:foreign_key]
          raise ArgumentError, ':as and :foreign_key options should be provided together to an association invocation'
        end

        class_name = options[:class_name]

        poly = options[:polymorphic] || !class_name.nil?
        as = options[:as] || field
        unscoped = !!options[:unscoped]

        klass = class_name.to_s if class_name

        foreign_key_method = (options[:foreign_key] || "#{field}_id").to_s
        foreign_type_method = foreign_key_method.gsub(/_id$/, '_type')

        if poly
          string foreign_type_method
        else
          class_eval <<-EV, __FILE__, __LINE__ + 1
            def #{foreign_type_method}
              #{as.to_s.camelize.inspect}
            end
          EV
        end

        integer foreign_key_method

        field_without_associations as, options.merge(association: true, field_writer: false, field_reader: false)

        class_eval <<-EV, __FILE__, __LINE__ + 1
          try(:silence_redefinition_of_method, :#{as})
          def #{as}
            return @#{as} if defined?(@#{as})
            @#{as} = polymorphic_instance(#{klass.nil? ? foreign_type_method : klass.to_s}, #{foreign_key_method}, #{unscoped.inspect})
          end

          try(:silence_redefinition_of_method, :#{as}=)
          def #{as}=(r)
            @#{as} = r
            #{poly || klass ? "send('#{foreign_type_method}=', r.nil? ? nil : #{klass.nil? ? 'r.class.name' : klass.to_s.inspect})" : ''}
            send('#{foreign_key_method}=', r.nil? ? nil : r.id)
            r
          end

          try(:silence_redefinition_of_method, :#{as}_field_provided?)
          def #{as}_field_provided?
            field_provided?('#{foreign_key_method}')#{poly ? "&& field_provided?('#{foreign_type_method}')" : ""}
          end
        EV
      end
    end

    def setup_fields_with_association(*args)
      setup_fields_without_association(*args)

      _fields.each_pair do |field, config|
        next unless config[:association]
        next if config[:mass_assignable] == false
        next unless @original_params.key?(field)

        send("#{field}=", @original_params[field]) # this gets the _id and _type into the params hash
      end
    end

    def polymorphic_instance(_type, _id, _unscoped = false)
      return nil unless _type && _id

      klass = _type
      klass = klass.classify.constantize if klass.is_a?(String)

      return nil unless klass

      scope = klass.all
      scope = scope.unscoped if _unscoped

      scope.find(_id)
    end
  end
end
