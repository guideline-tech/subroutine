# frozen_string_literal: true

require "test_helper"

module Subroutine
  class AuthTest < TestCase

    def user
      @user ||= ::User.new(id: 4, email_address: "doug@example.com")
    end

    def test_it_throws_an_error_if_authorization_is_not_defined
      assert_raises ::Subroutine::Auth::AuthorizationNotDeclaredError do
        MissingAuthOp.new
      end
    end

    def test_it_throws_an_error_if_require_user_but_none_is_provided
      assert_raises ::Subroutine::Auth::NotAuthorizedError do
        RequireUserOp.submit!
      end
    end

    def test_it_does_not_throw_an_error_if_require_user_but_none_is_provided
      RequireUserOp.submit! user
    end

    def test_it_allows_an_id_to_be_passed
      ::User.expects(:find).with(user.id).returns(user)
      op = RequireUserOp.submit! user.id
      assert_equal op.current_user, user
    end

    def test_it_throws_an_error_if_require_no_user_but_one_is_present
      assert_raises ::Subroutine::Auth::NotAuthorizedError do
        RequireNoUserOp.submit! user
      end
    end

    def test_it_does_not_throw_an_error_if_require_no_user_and_none_is_provided
      RequireNoUserOp.submit!
    end

    def test_it_does_not_throw_an_error_if_no_user_requirements_and_one_is_provided
      NoUserRequirementsOp.submit! user
    end

    def test_it_does_not_throw_an_error_if_no_user_requirements_and_none_is_provided
      NoUserRequirementsOp.submit!
    end

    def test_it_runs_custom_authorizations
      CustomAuthorizeOp.submit! user

      assert_raises ::Subroutine::Auth::NotAuthorizedError do
        CustomAuthorizeOp.submit! User.new(email_address: "foo@bar.com")
      end
    end

    def test_authorization_checks_are_registered_on_the_class
      assert_equal false, MissingAuthOp.authorization_declared?

      assert_equal true, CustomAuthorizeOp.authorization_declared?
      assert_equal [:authorize_user_required, :authorize_user_is_correct], CustomAuthorizeOp.authorization_checks

      assert_equal true, NoUserRequirementsOp.authorization_declared?
      assert_equal [:authorize_user_not_required], NoUserRequirementsOp.authorization_checks
    end

    def test_the_current_user_can_be_defined_by_an_id
      user = CustomAuthorizeOp.new(1).current_user
      assert_equal 1, user.id
      assert_equal true, user.is_a?(::User)
      assert_equal false, user.is_a?(::AdminUser)
    end

    def test_the_user_class_can_be_overridden
      user = DifferentUserClassOp.new(1).current_user
      assert_equal 1, user.id
      assert_equal true, user.is_a?(::AdminUser)
    end

    def test_another_class_cant_be_used_as_the_user
      assert_raises "current_user must be one of the following types {AdminUser,Integer,NilClass} but was String" do
        DifferentUserClassOp.new("doug")
      end
    end

    def test_it_does_not_run_authorizations_if_explicitly_bypassed
      op = CustomAuthorizeOp.new User.new(email_address: "foo@bar.com")
      op.skip_auth_checks!
      op.submit!
    end

    def test_it_runs_policies_as_part_of_authorization
      assert_raises ::Subroutine::Auth::NotAuthorizedError do
        PolicyOp.submit! user
      end

      op = PolicyOp.new
      op.skip_auth_checks!
      op.submit!
    end

    def policy_invocations_are_registered_as_authorization_methods
      assert PolicyOp.authorization_checks.include?(:authorize_policy_user_can_access)
    end

    def test_it_runs_policies_with_conditionals
      # if: false
      op = IfConditionalPolicyOp.new(user, check_policy: false)
      assert op.submit!
      # unless: true
      op = UnlessConditionalPolicyOp.new(user, unless_check_policy: true)
      assert op.submit!

      # if: true
      op = IfConditionalPolicyOp.new(user, check_policy: true)
      assert_raises ::Subroutine::Auth::NotAuthorizedError do
        op.submit!
      end

      # unless: false
      op = UnlessConditionalPolicyOp.new(user, unless_check_policy: false)
      assert_raises ::Subroutine::Auth::NotAuthorizedError do
        op.submit!
      end
    end

    def test_current_user_is_not_called_by_constructor
      ::User.expects(:find).never
      RequireUserOp.new(user.id)
    end

    def test_actioncontroller_parameters_can_be_provided
      raw_params = { some_input: "foobarbaz" }.with_indifferent_access
      params = ::ActionController::Parameters.new(raw_params)
      op = RequireUserOp.new(user, params)
      op.submit!

      assert_equal "foobarbaz", op.some_input

      assert_equal raw_params, op.params
      assert_equal user, op.current_user
    end

  end
end
