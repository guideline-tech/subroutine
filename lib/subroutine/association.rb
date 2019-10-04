# frozen_string_literal: true

module Subroutine
  module Association
    def self.included(base)
      base.send :extend, ::Subroutine::Association::ClassMethods
      class << base
        alias_method :field_without_associations, :field
        alias_method :field, :field_with_associations
      end

      base.send(:alias_method, :setup_fields_without_association, :setup_fields)
      base.send(:alias_method, :setup_fields, :setup_fields_with_association)
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

        field_without_associations as, options.merge(association: true)

        class_eval <<-EV, __FILE__, __LINE__ + 1
          def #{as}_with_association
            return @#{as} if defined?(@#{as})
            @#{as} = begin
              #{as}_without_association ||
              polymorphic_instance(#{klass.nil? ? foreign_type_method : klass.to_s}, #{foreign_key_method}, #{unscoped.inspect})
            end
          end

          def #{as}_with_association=(r)
            @#{as} = r
            #{poly || klass ? "params['#{foreign_type_method}'] = r.nil? ? nil : #{klass.nil? ? 'r.class.name' : klass.to_s.inspect}" : ''}
            params['#{foreign_key_method}'] = r.nil? ? nil : r.id
            r
          end

          def #{as}_field_provided?
            field_provided?('#{foreign_key_method}')#{poly ? "&& field_provided?('#{foreign_type_method}')" : ""}
          end
        EV

        alias_method :"#{as}_without_association", :"#{as}"
        alias_method :"#{as}", :"#{as}_with_association"

        alias_method :"#{as}_without_association=", :"#{as}="
        alias_method :"#{as}=", :"#{as}_with_association="
      end
    end

    def setup_fields_with_association(*args)
      setup_fields_without_association(*args)

      _fields.each_pair do |field, config|
        next unless config[:association]
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
