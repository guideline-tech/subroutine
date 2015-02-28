require 'test_helper'

module Opp
  class BaseTest < ::MiniTest::Test

    def test_simple_fields_definition
      op = ::SignupOp.new
      assert_equal ['email', 'password'], op._fields
    end

    def test_inherited_fields
      op = ::AdminSignupOp.new
      assert_equal ['email', 'password', 'priveleges'], op._fields
    end

    def test_class_attribute_usage
      assert ::AdminSignupOp < ::SignupOp

      sid = ::SignupOp._fields.object_id
      bid = ::AdminSignupOp._fields.object_id

      refute_equal sid, bid

      sid = ::SignupOp._defaults.object_id
      bid = ::AdminSignupOp._defaults.object_id

      refute_equal sid, bid

      sid = ::SignupOp._error_map.object_id
      bid = ::AdminSignupOp._error_map.object_id

      refute_equal sid, bid

    end

    def test_inputs_from_inherited_fields_without_inheriting_from_the_class
      refute ::BusinessSignupOp < ::SignupOp

      ::SignupOp._fields.each do |field|
        assert_includes ::BusinessSignupOp._fields, field
      end

      ::SignupOp._defaults.each_pair do |k,v|
        assert_equal v, ::BusinessSignupOp._defaults[k]
      end

      ::SignupOp._error_map.each_pair do |k,v|
        assert_equal v, ::BusinessSignupOp._error_map[k]
      end
    end

    def test_defaults_declaration_options
      assert_equal ::DefaultsOp._defaults, {
        'foo' => 'foo',
        'baz' => 'baz',
        'bar' => 'bar'
      }
    end

    def test_inherited_defaults_override_correctly
      assert_equal 'barstool', ::InheritedDefaultsOp._defaults['bar']
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

      err = assert_raises ::Opp::Failure do
        op.submit!
      end

      assert_equal "Password can't be blank", err.message
    end

    def test_it_allows_submission_from_the_class
      op = SignupOp.submit
      assert_equal ["can't be blank"], op.errors[:email]

      assert_raises ::Opp::Failure do
        SignupOp.submit!
      end

      op = SignupOp.submit! :email => 'foo@bar.com', :password => 'password123'
      assert_equal 'foo@bar.com', op.created_user.email_address

    end

  end
end
