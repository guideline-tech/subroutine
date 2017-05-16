require 'test_helper'

module Subroutine
  class TypeCasterTest < TestCase

    def op
      @op ||= TypeCastOp.new
    end

    def test_integer_inputs
      op.integer_input = nil
      assert_equal nil, op.integer_input

      op.integer_input = 'foo'
      assert_equal 0, op.integer_input

      op.integer_input = '4.5'
      assert_equal 4, op.integer_input

      op.integer_input = 0.5
      assert_equal 0, op.integer_input

      op.integer_input = 5.2
      assert_equal 5, op.integer_input

      op.integer_input = 6
      assert_equal 6, op.integer_input
    end

    def test_number_inputs
      op.number_input = nil
      assert_equal nil, op.number_input

      op.number_input = 4
      assert_equal 4.0, op.number_input

      op.number_input = 0.5
      assert_equal 0.5, op.number_input

      op.number_input = 'foo'
      assert_equal 0.0, op.number_input
    end

    def test_string_inputs
      op.string_input = nil
      assert_equal nil, op.string_input

      op.string_input = ""
      assert_equal '', op.string_input

      op.string_input = "foo"
      assert_equal 'foo', op.string_input

      op.string_input = 4
      assert_equal '4', op.string_input

      op.string_input = 4.2
      assert_equal '4.2', op.string_input
    end

    def test_boolean_inputs
      op.boolean_input = nil
      assert_equal nil, op.boolean_input

      op.boolean_input = 'yes'
      assert_equal true, op.boolean_input

      op.boolean_input = 'no'
      assert_equal false, op.boolean_input

      op.boolean_input = 'true'
      assert_equal true, op.boolean_input

      op.boolean_input = 'false'
      assert_equal false, op.boolean_input

      op.boolean_input = 'ok'
      assert_equal true, op.boolean_input

      op.boolean_input = ''
      assert_equal false, op.boolean_input

      op.boolean_input = true
      assert_equal true, op.boolean_input

      op.boolean_input = false
      assert_equal false, op.boolean_input

      op.boolean_input = '1'
      assert_equal true, op.boolean_input

      op.boolean_input = '0'
      assert_equal false, op.boolean_input

      op.boolean_input = 1
      assert_equal true, op.boolean_input

      op.boolean_input = 0
      assert_equal false, op.boolean_input
    end

    def test_hash_inputs
      op.object_input = nil
      assert_equal nil, op.object_input

      op.object_input = ''
      assert_equal({}, op.object_input)

      op.object_input = [[:a,:b]]
      assert_equal({"a" => :b}, op.object_input)

      op.object_input = false
      assert_equal({}, op.object_input)

      op.object_input = {foo: 'bar'}
      assert_equal({'foo' => 'bar'}, op.object_input)

      op.object_input = {"foo" => {"bar" => :baz}}
      assert_equal({"foo" => {"bar" => :baz}}, op.object_input)
    end

    def test_array_inputs
      op.array_input = nil
      assert_equal nil, op.array_input

      op.array_input = ''
      assert_equal [], op.array_input

      op.array_input = 'foo'
      assert_equal ['foo'], op.array_input

      op.array_input = ['foo']
      assert_equal ['foo'], op.array_input

      op.array_input = {"bar" => true}
      assert_equal [{"bar" => true}], op.array_input
    end

    def test_date_inputs
      op.date_input = nil
      assert_equal nil, op.date_input

      op.date_input = "2022-12-22"
      assert_equal ::Date, op.date_input.class
      refute_equal ::DateTime, op.date_input.class

      assert_equal 2022, op.date_input.year
      assert_equal 12, op.date_input.month
      assert_equal 22, op.date_input.day

      op.date_input = "2023-05-05T10:00:30"
      assert_equal ::Date, op.date_input.class
      refute_equal ::DateTime, op.date_input.class

      assert_equal 2023, op.date_input.year
      assert_equal 5, op.date_input.month
      assert_equal 5, op.date_input.day

      op.date_input = "2020-05-03 13:44:45 -0400"

      assert_equal ::Date, op.date_input.class
      refute_equal ::DateTime, op.date_input.class

      assert_equal 2020, op.date_input.year
      assert_equal 5, op.date_input.month
      assert_equal 3, op.date_input.day

      op.date_input = false
      assert_nil op.date_input
    end


    def test_time_inputs
      op.time_input = nil
      assert_equal nil, op.time_input

      op.time_input = "2022-12-22"
      assert_equal ::Time, op.time_input.class
      refute_equal ::DateTime, op.time_input.class

      assert_equal 2022, op.time_input.year
      assert_equal 12, op.time_input.month
      assert_equal 22, op.time_input.day
      assert_equal 0, op.time_input.hour
      assert_equal 0, op.time_input.min
      assert_equal 0, op.time_input.sec

      op.time_input = "2023-05-05T10:00:30Z"
      assert_equal ::Time, op.time_input.class
      refute_equal ::DateTime, op.time_input.class

      assert_equal 2023, op.time_input.year
      assert_equal 5, op.time_input.month
      assert_equal 5, op.time_input.day
      assert_equal 10, op.time_input.hour
      assert_equal 0, op.time_input.min
      assert_equal 30, op.time_input.sec
    end

    def test_iso_date_inputs
      op.iso_date_input = nil
      assert_equal nil, op.iso_date_input

      op.iso_date_input = "2022-12-22"
      assert_equal ::String, op.iso_date_input.class
      assert_equal "2022-12-22", op.iso_date_input

      op.iso_date_input = Date.parse("2022-12-22")
      assert_equal ::String, op.iso_date_input.class
      assert_equal "2022-12-22", op.iso_date_input
    end

    def test_iso_time_inputs
      op.iso_time_input = nil
      assert_equal nil, op.iso_time_input

      op.iso_time_input = "2022-12-22T10:30:24Z"
      assert_equal ::String, op.iso_time_input.class
      assert_equal "2022-12-22T10:30:24Z", op.iso_time_input

      op.iso_time_input = Time.parse("2022-12-22T10:30:24Z")
      assert_equal ::String, op.iso_time_input.class
      assert_equal "2022-12-22T10:30:24Z", op.iso_time_input
    end

    def test_field_provided
      op = ::SignupOp.new()
      assert_equal false, op.send(:field_provided?, :email)

      op = ::SignupOp.new(email: "foo")
      assert_equal true, op.send(:field_provided?, :email)

      op = ::DefaultsOp.new()
      assert_equal false, op.send(:field_provided?, :foo)

      op = ::DefaultsOp.new(foo: "foo")
      assert_equal true, op.send(:field_provided?, :foo)
    end

  end
end
