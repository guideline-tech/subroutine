module Subroutine
  module Auth

    class NotAuthorizedError < ::StandardError

      def initialize(msg = nil)
        msg = I18n.t("errors.#{msg}", default: "Sorry, you are not authorized to perform this action.") if msg.is_a?(Symbol)
        msg ||= I18n.t('errors.unauthorized', default: "Sorry, you are not authorized to perform this action.")
        super msg
      end

      def status
        401
      end

    end

    def self.included(base)
      base.instance_eval do
        extend ::Subroutine::Auth::ClassMethods

        class_attribute :authorization_declared
        self.authorization_declared = false
      end
    end


    module ClassMethods

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
      # policy :can_do_whatever, policy: :foo_policy
      def policy(*meths)
        opts = meths.extract_options!
        policy_name = opts[:policy] || :policy
        validate unless: :skip_auth_checks? do
          p = self.send(policy_name)
          if !p || meths.any?{|m| !(p.respond_to?("#{m}?") ? p.send("#{m}?") : p.send(m)) }
            unauthorized! opts[:error]
          end
        end
      end

    end

    def initialize(*args)
      raise "Authorization management has not been declared on this class" if(!self.class.authorization_declared)

      super(args.extract_options!)
      @skip_auth_checks = false
      @current_user = args.shift
    end

    def skip_auth_checks!
      @skip_auth_checks = true
      self
    end

    def skip_auth_checks?
      !!@skip_auth_checks
    end

    def current_user
      @current_user = ::User.find(@current_user) if Fixnum === @current_user
      @current_user
    end

    def unauthorized!(reason = nil)
      reason ||= :unauthorized
      raise ::Subroutine::Auth::NotAuthorizedError.new(reason)
    end

  end
end
