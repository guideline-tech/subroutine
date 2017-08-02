require 'test_helper'

module Subroutine
  class AuthTest < TestCase

    def user
      @user ||= ::User.new(email_address: "doug@example.com")
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

  end
end
