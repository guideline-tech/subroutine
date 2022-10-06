# frozen_string_literal: true

require 'test_helper'

module Subroutine
  class OutputsTest < TestCase
    class MissingOutputOp < ::Subroutine::Op
      def perform
        output :foo, 'bar'
      end
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

    class DynamicRequireCheck < ::Subroutine::Op
      outputs :foo, required: -> { the_check }

      class << self
        def the_check
          nil
        end
      end

      def perform; end
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

    def test_it_allows_dynamic_requirement_checks
      op = DynamicRequireCheck.new
      DynamicRequireCheck.stubs(:the_check).returns(true)

      assert_raises ::Subroutine::Outputs::OutputNotSetError do
        op.submit
      end

      DynamicRequireCheck.stubs(:the_check).returns(false)

      assert op.submit
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

  end
end
