# frozen_string_literal: true

require 'test_helper'

module Subroutine
  class OutputsTest < TestCase
    class MissingOutputOp < ::Subroutine::Op
      def perform
        output :foo, 'bar'
      end
    end

    class LazyOutputOp < ::Subroutine::Op
      outputs :foo, lazy: true
      outputs :baz, lazy: true, type: String

      def perform
        output :foo, -> { call_me }
        output :baz, -> { call_baz }
      end

      def call_me; end

      def call_baz; end
    end

    class MissingOutputSetOp < ::Subroutine::Op
      outputs :foo
      def perform
        true
      end
    end

    class OutputNotRequiredOp < ::Subroutine::Op
      outputs :foo, required: false
      def perform
        true
      end
    end

    class NoOutputNoSuccessOp < ::Subroutine::Op
      outputs :foo

      def perform
        errors.add(:foo, 'bar')
      end
    end

    class OutputWithTypeValidationNotRequired < ::Subroutine::Op
      outputs :value, type: String, required: false

      def perform; end
    end

    class OutputWithTypeValidationRequired < ::Subroutine::Op
      outputs :value, type: String, required: true

      def perform; end
    end

    def test_it_raises_an_error_if_an_output_is_not_defined_but_is_set
      op = MissingOutputOp.new
      assert_raises ::Subroutine::Outputs::UnknownOutputError do
        op.submit
      end
    end

    def test_it_raises_an_error_if_not_all_outputs_were_set
      op = MissingOutputSetOp.new
      assert_raises ::Subroutine::Outputs::OutputNotSetError do
        op.submit
      end
    end

    def test_it_does_not_raise_an_error_if_output_is_not_set_and_is_not_required
      op = OutputNotRequiredOp.new
      op.submit
    end

    def test_it_does_not_raise_an_error_if_the_perform_is_not_a_success
      op = NoOutputNoSuccessOp.new
      refute op.submit
    end

    ###################
    # type validation #
    ###################

    def test_it_does_not_raise_an_error_if_output_is_set_to_the_right_type
      op = OutputWithTypeValidationNotRequired.new
      op.send(:output, :value, 'foo')
      assert op.submit
    end

    def test_it_raises_an_error_if_output_is_not_set_to_the_right_type
      op = OutputWithTypeValidationNotRequired.new
      op.send(:output, :value, 1)
      assert_raises ::Subroutine::Outputs::InvalidOutputTypeError do
        op.submit
      end
    end

    def test_it_does_not_raise_an_error_if_output_is_set_to_nil_when_there_is_type_validation_and_not_required
      op = OutputWithTypeValidationNotRequired.new
      op.send(:output, :value, nil)
      op.submit
    end

    def test_it_raises_an_error_if_output_is_set_to_nil_when_there_is_type_validation_and_is_required
      op = OutputWithTypeValidationRequired.new
      op.send(:output, :value, nil)
      assert_raises ::Subroutine::Outputs::InvalidOutputTypeError do
        op.submit
      end
    end

    ################
    # lazy outputs #
    ################

    def test_it_does_not_call_lazy_output_values_if_not_accessed
      op = LazyOutputOp.new
      op.expects(:call_me).never
      op.submit!
    end

    def test_it_calls_lazy_output_values_if_accessed
      op = LazyOutputOp.new
      op.expects(:call_me).once
      op.submit!
      op.foo
    end

    def test_it_validates_type_when_lazy_output_is_accessed
      op = LazyOutputOp.new
      op.expects(:call_baz).once.returns("a string")
      op.submit!
      assert_silent do
        op.baz
      end
    end

    def test_it_raises_error_on_invalid_type_when_lazy_output_is_accessed
      op = LazyOutputOp.new
      op.expects(:call_baz).once.returns(10)
      op.submit!
      error = assert_raises(Subroutine::Outputs::InvalidOutputTypeError) do
        op.baz
      end
      assert_match(/Invalid output type for 'baz' expected String but got Integer/, error.message)
    end

    def test_it_returns_outputs
      op = LazyOutputOp.new
      op.expects(:call_me).once.returns(1)
      op.expects(:call_baz).once.returns("a string")
      op.submit!
      assert_equal({ foo: 1, baz: "a string" }, op.outputs)
    end

  end
end
