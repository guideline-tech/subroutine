# frozen_string_literal: true

module Subroutine
  module Extensions
    module Auth

      extend ActiveSupport::Concern

      class NotAuthorizedError < ::StandardError

        def initialize(msg = nil)
          msg = I18n.t("errors.#{msg}", default: "Sorry, you are not authorized to perform this action.") if msg.is_a?(Symbol)
          msg ||= I18n.t("errors.unauthorized", default: "Sorry, you are not authorized to perform this action.")
          super msg
        end

        def status
          401
        end

      end

      class AuthorizationNotDeclaredError < ::StandardError

        def initialize(msg = nil)
          super(msg || "Authorization management has not been declared on this class")
        end

      end

      included do
        class_attribute :authorization_declared, instance_writer: false
        self.authorization_declared = false

        class_attribute :user_class_name, instance_writer: false
        self.user_class_name = "User"
      end

      module ClassMethods

        def supported_user_class_names
          [user_class_name, "Integer", "NilClass"].compact
        end

        def authorize(validation_name)
          validate validation_name, unless: :skip_auth_checks?
        end

        def no_user_requirements!
          self.authorization_declared = true
        end

        def require_user!
          self.authorization_declared = true

          validate unless: :skip_auth_checks? do
            unauthorized! unless current_user.present?
          end
        end

        def require_no_user!
          self.authorization_declared = true

          validate unless: :skip_auth_checks? do
            unauthorized! :empty_unauthorized if current_user.present?
          end
        end

        # policy :can_update_user
        # policy :can_update_user, unless: :dont_do_it
        # policy :can_update_user, if: :do_it
        # policy :can_do_whatever, policy: :foo_policy
        def policy(*meths)
          opts = meths.extract_options!
          policy_name = opts[:policy] || :policy

          if_conditionals = Array(opts[:if])
          unless_conditionals = Array(opts[:unless])

          validate unless: :skip_auth_checks? do
            run_it = true
            # http://guides.rubyonrails.org/active_record_validations.html#combining-validation-conditions

            # The validation only runs when all the :if conditions
            if if_conditionals.present?
              run_it &&= if_conditionals.all? { |i| send(i) }
            end

            # and none of the :unless conditions are evaluated to true.
            if unless_conditionals.present?
              run_it &&= unless_conditionals.none? { |u| send(u) }
            end

            next unless run_it

            p = send(policy_name)
            if !p || meths.any? { |m| !(p.respond_to?("#{m}?") ? p.send("#{m}?") : p.send(m)) }
              unauthorized! opts[:error]
            end
          end
        end

      end

      def initialize(*args, &block)
        raise Subroutine::Extensions::Auth::AuthorizationNotDeclaredError unless self.class.authorization_declared

        super(args.extract_options!, &block)
        @skip_auth_checks = false
        @current_user = args.shift

        unless self.class.supported_user_class_names.include?(@current_user.class.name)
          raise ArgumentError, "current_user must be one of the following types {#{self.class.supported_user_class_names.join(",")}} but was #{@current_user.class.name}"
        end
      end

      def skip_auth_checks!
        @skip_auth_checks = true
        self
      end

      def skip_auth_checks?
        !!@skip_auth_checks
      end

      def current_user
        @current_user = user_class_name.constantize.find(@current_user) if ::Integer === @current_user
        @current_user
      end

      def unauthorized!(reason = nil)
        reason ||= :unauthorized
        raise ::Subroutine::Extensions::Auth::NotAuthorizedError, reason
      end

    end
  end
end
