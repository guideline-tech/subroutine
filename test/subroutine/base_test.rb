require 'test_helper'

module Subroutine
  class OpTest < TestCase

    def test_simple_fields_definition
      op = ::SignupOp.new
      assert_equal [:email, :password], op._fields.keys.sort
    end

    def test_inherited_fields
      op = ::AdminSignupOp.new
      assert_equal [:email, :password, :priveleges], op._fields.keys.sort
    end

    def test_class_attribute_usage
      assert ::AdminSignupOp < ::SignupOp

      sid = ::SignupOp._fields.object_id
      bid = ::AdminSignupOp._fields.object_id

      refute_equal sid, bid
    end

    def test_inputs_from_inherited_fields_without_inheriting_from_the_class
      refute ::BusinessSignupOp < ::SignupOp

      user_fields = ::SignupOp._fields.keys
      biz_fields = ::BusinessSignupOp._fields.keys

      user_fields.each do |field|
        assert_includes biz_fields, field
      end
    end

    def test_defaults_declaration_options
      op = ::DefaultsOp.new
      assert_equal 'foo', op.foo
      assert_equal 'bar', op.bar
      assert_equal false, op.baz
    end

    def test_inherited_defaults_override_correctly
      op = ::InheritedDefaultsOp.new
      assert_equal 'barstool', op.bar
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
      assert_equal 'min', op.priveleges

      op.priveleges = 'max'
      assert_equal 'max', op.priveleges
    end

    def test_validations_are_evaluated_before_perform_is_invoked
      op = ::SignupOp.new

      refute op.submit

      refute op.perform_called

      assert_equal ["can't be blank"], op.errors[:email]
    end

    def test_validation_errors_can_be_inherited_and_transformed
      op = ::AdminSignupOp.new(:email => 'foo@bar.com', :password => 'password123')

      refute op.submit

      assert op.perform_called
      refute op.perform_finished

      assert_equal ["has gotta be @admin.com"], op.errors[:email]
    end

    def test_when_valid_perform_completes_it_returns_control
      op = ::SignupOp.new(:email => 'foo@bar.com', :password => 'password123')
      op.submit!

      assert op.perform_called
      assert op.perform_finished

      u = op.created_user

      assert_equal 'foo@bar.com', u.email_address
    end

    def test_it_raises_an_error_when_used_with_a_bang_and_performing_or_validation_fails
      op = ::SignupOp.new(:email => 'foo@bar.com')

      err = assert_raises ::Subroutine::Failure do
        op.submit!
      end

      assert_equal "Password can't be blank", err.message
    end

    def test_it_allows_submission_from_the_class
      op = SignupOp.submit
      assert_equal ["can't be blank"], op.errors[:email]

      assert_raises ::Subroutine::Failure do
        SignupOp.submit!
      end

      op = SignupOp.submit! :email => 'foo@bar.com', :password => 'password123'
      assert_equal 'foo@bar.com', op.created_user.email_address

    end

    def test_it_ignores_specific_errors
      op = ::WhateverSignupOp.submit
      assert_equal [], op.errors[:whatever]
    end

    def test_it_does_not_inherit_ignored_errors
      op = ::WhateverSignupOp.new
      other = ::SignupOp.new
      other.errors.add(:whatever, "fail")
      op.send(:inherit_errors, other)
      assert_equal [], op.errors[:whatever]
    end

    def test_it_sets_the_params_and_defaults_immediately
      op = ::AdminSignupOp.new(email: "foo")
      assert_equal({
        "email" => "foo"
      }, op.params)

      assert_equal({
        "priveleges" => "min",
      }, op.defaults)

      assert_equal({
        "email" => "foo",
        "priveleges" => "min",
      }, op.params_with_defaults)
    end

    def test_it_allows_defaults_to_be_overridden
      op = ::AdminSignupOp.new(email: "foo", priveleges: nil)

      assert_equal({
        "email" => "foo",
        "priveleges" => nil
      }, op.params)

      assert_equal({
        "priveleges" => "min",
      }, op.defaults)

      assert_equal({
        "email" => "foo",
        "priveleges" => nil,
      }, op.params_with_defaults)
    end

    def test_it_overrides_defaults_with_nils
      op = ::AdminSignupOp.new(email: "foo", priveleges: nil)
      assert_equal({
        "priveleges" => nil,
        "email" => "foo"
      }, op.params)
    end

    def test_it_casts_params_on_the_way_in
      op = ::TypeCastOp.new(integer_input: "25")
      assert_equal(25, op.params_with_defaults["integer_input"])

      op.decimal_input = "25.3"
      assert_equal(BigDecimal("25.3"), op.params_with_defaults["decimal_input"])
    end

    def test_it_allow_retrival_of_outputs
      op = ::SignupOp.submit!(:email => 'foo@bar.com', :password => 'password123')
      u = op.created_user

      assert_equal "foo@bar.com", u.email_address
    end

    def test_it_raises_an_error_if_an_output_is_not_defined_but_is_set
      op = ::MissingOutputOp.new
      assert_raises ::Subroutine::UnknownOutputError do
        op.submit
      end
    end

    def test_it_raises_an_error_if_not_all_outputs_were_set
      op = ::MissingOutputSetOp.new
      assert_raises ::Subroutine::OutputNotSetError do
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

  end
end
