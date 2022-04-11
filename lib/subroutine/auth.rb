# frozen_string_literal: true

require "subroutine/auth/authorization_not_declared_error"
require "subroutine/auth/not_authorized_error"

module Subroutine
  module Auth

    extend ActiveSupport::Concern

    included do
      class_attribute :authorization_checks
      self.authorization_checks = []

      class_attribute :user_class_name, instance_writer: false
      self.user_class_name = "User"

      validate :validate_authorization_checks, unless: :skip_auth_checks?
    end

    module ClassMethods

      def supported_user_class_names
        [user_class_name, "Integer", "NilClass"].compact
      end

      def authorization_declared?
        authorization_checks.any?
      end

      def authorize(check_name)
        self.authorization_checks += [check_name.to_sym]
      end

      def no_user_requirements!
        authorize :authorize_user_not_required
      end

      def require_user!
        authorize :authorize_user_required
      end

      def require_no_user!
        authorize :authorize_no_user_required
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

        meths.each do |meth|
          normalized_meth = meth[0...-1] if meth.end_with?("?")
          auth_method_name = :"authorize_#{policy_name}_#{normalized_meth}"

          define_method auth_method_name do
            run_it = true
            # http://guides.rubyonrails.org/active_record_validations.html#combining-validation-conditions

            # The validation only runs when all the :if conditions evaluate to true
            if if_conditionals.present?
              run_it &&= if_conditionals.all? { |i| send(i) }
            end

            # and none of the :unless conditions are evaluated to true.
            if unless_conditionals.present?
              run_it &&= unless_conditionals.none? { |u| send(u) }
            end

            return unless run_it

            p = send(policy_name)
            unauthorized! unless p

            result = if p.respond_to?("#{normalized_meth}?")
                       p.send("#{normalized_meth}?")
                     else
                       p.send(normalized_meth)
                     end

            unauthorized! opts[:error] unless result
          end

          authorize auth_method_name
        end
      end
    end

    def initialize(*args, &block)
      raise Subroutine::Auth::AuthorizationNotDeclaredError unless self.class.authorization_declared?

      @skip_auth_checks = false

      inputs = case args.last
      when *::Subroutine::Fields.allowed_input_classes
        args.pop
      else
        {}
      end

      super(inputs, &block)

      user = args.shift

      unless self.class.supported_user_class_names.include?(user.class.name)
        raise ArgumentError, "current_user must be one of the following types {#{self.class.supported_user_class_names.join(",")}} but was #{user.class.name}"
      end

      @current_user = user
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
      raise ::Subroutine::Auth::NotAuthorizedError, reason
    end

    def validate_authorization_checks
      authorization_checks.each do |check|
        send(check)
      end
    end

    def authorize_user_not_required
      true
    end

    def authorize_user_required
      unauthorized! unless current_user.present?
    end

    def authorize_no_user_required
      unauthorized! :empty_unauthorized if current_user.present?
    end

  end
end
