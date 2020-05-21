# frozen_string_literal: true

require "test_helper"

module Subroutine
  class OpTest < TestCase

    def test_simple_fields_definition
      op = ::SignupOp.new
      assert_equal %i[email password], op.field_configurations.keys.sort
    end

    def test_inherited_fields
      op = ::AdminSignupOp.new
      assert_equal %i[email password privileges], op.field_configurations.keys.sort
    end

    def test_class_attribute_usage
      assert ::AdminSignupOp < ::SignupOp

      sid = ::SignupOp.field_configurations.object_id
      bid = ::AdminSignupOp.field_configurations.object_id

      refute_equal sid, bid
    end

    def test_fields_from_inherited_fields_without_inheriting_from_the_class
      refute ::BusinessSignupOp < ::SignupOp

      user_fields = ::SignupOp.field_configurations.keys
      biz_fields = ::BusinessSignupOp.field_configurations.keys

      user_fields.each do |field|
        assert_includes biz_fields, field
      end
    end

    def test_fields_from_ignores_except_fields
      op = ::ExceptFooBarOp.new
      refute op.field_configurations.key?(:foo)
      refute op.field_configurations.key?(:bar)
      assert_equal [:baz], op.field_configurations.keys.sort
    end

    def test_fields_from_ignores_except_association_fields
      op = ::ExceptAssociationOp.new
      refute op.field_configurations.key?(:admin)
      refute op.field_configurations.key?(:admin_id)
      refute op.field_configurations.key?(:admin_type)
    end

    def test_fields_from_only_fields
      op = ::OnlyFooBarOp.new
      assert op.field_configurations.key?(:foo)
      assert op.field_configurations.key?(:bar)
      refute_equal [:baz], op.field_configurations.keys.sort
    end

    def test_fields_from_only_association_fields
      op = ::OnlyAssociationOp.new
      assert op.field_configurations.key?(:admin)
      assert op.field_configurations.key?(:admin_type)
      assert op.field_configurations.key?(:admin_id)
    end

    def test_defaults_declaration_options
      op = ::DefaultsOp.new
      assert_equal "foo", op.foo
      assert_equal "bar", op.bar
      assert_equal false, op.baz
    end

    def test_inherited_defaults_override_correctly
      op = ::InheritedDefaultsOp.new
      assert_equal "barstool", op.bar
    end

    def test_accessors_are_created
      op = ::SignupOp.new

      assert_respond_to op, :email
      assert_respond_to op, :email=

      assert_respond_to op, :password
      assert_respond_to op, :password=

      refute_respond_to ::SignupOp, :email
      refute_respond_to ::SignupOp, :email=
      refute_respond_to ::SignupOp, :password
      refute_respond_to ::SignupOp, :password=
    end

    def test_defaults_are_applied_to_new_instances
      op = ::SignupOp.new

      assert_nil op.email
      assert_nil op.password

      op = ::AdminSignupOp.new

      assert_nil op.email
      assert_nil op.password
      assert_equal "min", op.privileges

      op.privileges = "max"
      assert_equal "max", op.privileges
    end

    def test_validations_are_evaluated_before_perform_is_invoked
      op = ::SignupOp.new

      refute op.submit

      refute op.perform_called

      assert_equal ["can't be blank"], op.errors[:email]
    end

    def test_validation_errors_can_be_inherited_and_transformed
      op = ::AdminSignupOp.new(email: "foo@bar.com", password: "password123")

      refute op.submit

      assert op.perform_called
      refute op.perform_finished

      assert_equal ["has gotta be @admin.com"], op.errors[:email]
    end

    def test_when_valid_perform_completes_it_returns_control
      op = ::SignupOp.new(email: "foo@bar.com", password: "password123")
      op.submit!

      assert op.perform_called
      assert op.perform_finished

      u = op.created_user

      assert_equal "foo@bar.com", u.email_address
    end

    def test_it_raises_an_error_when_used_with_a_bang_and_performing_or_validation_fails
      op = ::SignupOp.new(email: "foo@bar.com")

      err = assert_raises ::Subroutine::Failure do
        op.submit!
      end

      assert_equal "Password can't be blank", err.message
    end

    def test_uses_failure_class_to_raise_error
      op = ::CustomFailureClassOp.new

      err = assert_raises ::CustomFailureClassOp::Failure do
        op.submit!
      end

      assert_equal "Will never work", err.message
    end

    def test_the_result_of_perform_doesnt_matter
      op = ::FalsePerformOp.new
      assert op.submit!
    end

    def test_it_allows_submission_from_the_class
      op = SignupOp.submit
      assert_equal ["can't be blank"], op.errors[:email]

      assert_raises ::Subroutine::Failure do
        SignupOp.submit!
      end

      op = SignupOp.submit! email: "foo@bar.com", password: "password123"
      assert_equal "foo@bar.com", op.created_user.email_address
    end

    def test_it_sets_the_params_and_defaults_immediately
      op = ::AdminSignupOp.new(email: "foo")
      assert_equal({
        "email" => "foo",
      }, op.params)

      assert_equal({
        "privileges" => "min",
      }, op.defaults)

      assert_equal({
        "email" => "foo",
        "privileges" => "min",
      }, op.params_with_defaults)
    end

    def test_it_allows_defaults_to_be_overridden
      op = ::AdminSignupOp.new(email: "foo", privileges: nil)

      assert_equal({
        "email" => "foo",
        "privileges" => nil,
      }, op.params)

      assert_equal({ "privileges" => "min" }, op.defaults)
    end

    def test_it_overriding_default_does_not_alter_default
      op = ::AdminSignupOp.new(email: "foo")
      op.privileges << "bangbang"

      op = ::AdminSignupOp.new(email: "foo", privileges: nil)

      assert_equal({
        "email" => "foo",
        "privileges" => nil,
      }, op.params)

      assert_equal({
        "privileges" => "min",
      }, op.defaults)
    end

    def test_it_overrides_defaults_with_nils
      op = ::AdminSignupOp.new(email: "foo", privileges: nil)
      assert_equal({
        "privileges" => nil,
        "email" => "foo",
      }, op.params)
    end

    def test_it_casts_params_on_the_way_in
      op = ::TypeCastOp.new(integer_input: "25")
      assert_equal(25, op.params["integer_input"])

      op.decimal_input = "25.3"
      assert_equal(BigDecimal("25.3"), op.params["decimal_input"])
    end

    def test_it_allow_retrival_of_outputs
      op = ::SignupOp.submit!(email: "foo@bar.com", password: "password123")
      u = op.created_user

      assert_equal "foo@bar.com", u.email_address
    end

    # Hash#with_indifferent_access was changing output objects
    def test_outputs_are_not_mutated
      out = { "foo" => "bar" }
      op = ::SignupOp.new
      op.send :output, :perform_called, out
      value = op.perform_called
      assert_equal out, value
      assert_equal Hash, value.class
    end

    def test_it_raises_an_error_if_an_output_is_not_defined_but_is_set
      op = ::MissingOutputOp.new
      assert_raises ::Subroutine::Outputs::UnknownOutputError do
        op.submit
      end
    end

    def test_it_raises_an_error_if_not_all_outputs_were_set
      op = ::MissingOutputSetOp.new
      assert_raises ::Subroutine::Outputs::OutputNotSetError do
        op.submit
      end
    end

    def test_it_does_not_raise_an_error_if_output_is_not_set_and_is_not_required
      op = ::OutputNotRequiredOp.new
      op.submit
    end

    def test_it_does_not_raise_an_error_if_the_perform_is_not_a_success
      op = ::NoOutputNoSuccessOp.new
      refute op.submit
    end

    def test_it_does_not_omit_the_backtrace_from_the_original_error
      op = ::ErrorTraceOp.new
      begin
        op.submit!
      rescue Exception => e
        found = e.backtrace.detect do |msg|
          msg =~ %r{test/support/ops\.rb:[\d]+.+foo}
        end

        refute_nil found, "Expected backtrace to include original caller of foo"
      end
    end

    def test_a_block_is_accepted_on_instantiation
      op = ::SignupOp.new do |o|
        o.email = "foo@bar.com"
        o.password = "password123!"
      end

      assert_equal "foo@bar.com", op.email
      assert_equal "password123!", op.password

      assert_equal true, op.field_provided?(:email)
      assert_equal true, op.field_provided?(:password)
    end

    def test_a_block_is_not_accepted_with_submit
      assert_raises ::ArgumentError do
        ::SignupOp.submit! do |o|
          o.email = "foo@bar.com"
          o.password = "password123!"
        end
      end

      assert_raises ::ArgumentError do
        ::SignupOp.submit do |o|
          o.email = "foo@bar.com"
          o.password = "password123!"
        end
      end
    end

    def test_actioncontroller_parameters_can_be_provided
      raw_params = { email: "foo@bar.com", password: "password123!" }.with_indifferent_access
      params = ::ActionController::Parameters.new(raw_params)
      op = SignupOp.new(params)
      op.submit!

      assert_equal "foo@bar.com", op.email
      assert_equal "password123!", op.password

      assert_equal raw_params, op.params
    end

  end
end
