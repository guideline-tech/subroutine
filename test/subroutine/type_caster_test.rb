# frozen_string_literal: true

require 'test_helper'

module Subroutine
  class TypeCasterTest < TestCase
    def op
      @op ||= TypeCastOp.new
    end

    def test_integer_inputs
      op.integer_input = nil
      assert_nil op.integer_input

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
      assert_nil op.number_input

      op.number_input = 4
      assert_equal 4.0, op.number_input

      op.number_input = 0.5
      assert_equal 0.5, op.number_input

      op.number_input = 'foo'
      assert_equal 0.0, op.number_input
    end

    def test_decimal_inputs
      op.decimal_input = nil
      assert_nil op.decimal_input

      op.decimal_input = 4
      assert_equal 4.0, op.decimal_input
      assert op.decimal_input.is_a?(BigDecimal)

      op.decimal_input = 0.5
      assert_equal 0.5, op.decimal_input

      op.decimal_input = 'foo'
      assert_equal 0.0, op.decimal_input
    end

    def test_decimal_inputs_use_16_precision
      op.decimal_input = 0.07
      expected_bd_value = BigDecimal('0.07', 0)
      assert_equal expected_bd_value, op.decimal_input
      assert op.decimal_input.is_a?(BigDecimal)

      # Ruby 3+
      if op.decimal_input.respond_to?(:precision)
        assert_equal expected_bd_value.precision, op.decimal_input.precision
      end
    end

    def test_string_inputs
      op.string_input = nil
      assert_nil op.string_input

      op.string_input = "
      assert_equal ", op.string_input

      op.string_input = 'foo'
      assert_equal 'foo', op.string_input

      op.string_input = 4
      assert_equal '4', op.string_input

      op.string_input = 4.2
      assert_equal '4.2', op.string_input
    end

    def test_boolean_inputs
      op.boolean_input = nil
      assert_nil op.boolean_input

      op.boolean_input = 'yes'
      assert_equal true, op.boolean_input

      op.boolean_input = 'no'
      assert_equal false, op.boolean_input

      op.boolean_input = 'Yes'
      assert_equal true, op.boolean_input

      op.boolean_input = 'No'
      assert_equal false, op.boolean_input

      op.boolean_input = 'YES'
      assert_equal true, op.boolean_input

      op.boolean_input = 'NO'
      assert_equal false, op.boolean_input

      op.boolean_input = 'true'
      assert_equal true, op.boolean_input

      op.boolean_input = 'false'
      assert_equal false, op.boolean_input

      op.boolean_input = 'True'
      assert_equal true, op.boolean_input

      op.boolean_input = 'False'
      assert_equal false, op.boolean_input

      op.boolean_input = 'TRUE'
      assert_equal true, op.boolean_input

      op.boolean_input = 'FALSE'
      assert_equal false, op.boolean_input

      op.boolean_input = 'ok'
      assert_equal true, op.boolean_input

      op.boolean_input = 'OK'
      assert_equal true, op.boolean_input

      op.boolean_input = 'Ok'
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
      assert_nil op.object_input

      op.object_input = ''
      assert_equal({}, op.object_input)

      op.object_input = [[:a, :b]]
      assert_equal({ 'a' => :b }, op.object_input)

      op.object_input = false
      assert_equal({}, op.object_input)

      op.object_input = { foo: 'bar' }
      assert_equal({ 'foo' => 'bar' }, op.object_input)

      op.object_input = { 'foo' => { 'bar' => :baz } }
      assert_equal({ 'foo' => { 'bar' => :baz } }, op.object_input)
    end

    def test_array_inputs
      op.array_input = nil
      assert_nil op.array_input

      op.array_input = ''
      assert_equal [], op.array_input

      op.array_input = 'foo'
      assert_equal ['foo'], op.array_input

      op.array_input = ['foo']
      assert_equal ['foo'], op.array_input

      op.array_input = { 'bar' => true }
      assert_equal [{ 'bar' => true }], op.array_input
    end

    def test_typed_array_inputs
      op.type_array_input = nil
      assert_nil op.type_array_input

      op.type_array_input = ''
      assert_equal [], op.type_array_input

      op.type_array_input = '3'
      assert_equal [3], op.type_array_input

      op.type_array_input = ['3.4']
      assert_equal [3], op.type_array_input
    end

    def test_date_inputs
      op.date_input = nil
      assert_nil op.date_input

      op.date_input = '2022-12-22'
      assert_equal ::Date, op.date_input.class
      refute_equal ::DateTime, op.date_input.class

      assert_equal 2022, op.date_input.year
      assert_equal 12, op.date_input.month
      assert_equal 22, op.date_input.day

      op.date_input = '2023-05-05T10:00:30'
      assert_equal ::Date, op.date_input.class
      refute_equal ::DateTime, op.date_input.class

      assert_equal 2023, op.date_input.year
      assert_equal 5, op.date_input.month
      assert_equal 5, op.date_input.day

      op.date_input = '2020-05-03 13:44:45 -0400'

      assert_equal ::Date, op.date_input.class
      refute_equal ::DateTime, op.date_input.class

      assert_equal 2020, op.date_input.year
      assert_equal 5, op.date_input.month
      assert_equal 3, op.date_input.day

      op.date_input = false
      assert_nil op.date_input
    end

    def test_time_inputs__with_seconds_precision
      op.time_input = nil
      assert_nil op.time_input

      op.time_input = '2022-12-22'
      assert_equal ::Time, op.time_input.class
      refute_equal ::DateTime, op.time_input.class

      assert_equal 2022, op.time_input.year
      assert_equal 12, op.time_input.month
      assert_equal 22, op.time_input.day
      assert_equal 0, op.time_input.hour
      assert_equal 0, op.time_input.min
      assert_equal 0, op.time_input.sec

      op.time_input = ::DateTime.new(2022, 12, 22)
      assert_equal ::Time, op.time_input.class
      refute_equal ::DateTime, op.time_input.class

      assert_equal 0, op.time_input.utc_offset
      assert_equal 2022, op.time_input.year
      assert_equal 12, op.time_input.month
      assert_equal 22, op.time_input.day
      assert_equal 0, op.time_input.hour
      assert_equal 0, op.time_input.min
      assert_equal 0, op.time_input.sec

      op.time_input = '2023-05-05T10:00:30.123456Z'
      assert_equal ::Time, op.time_input.class
      refute_equal ::DateTime, op.time_input.class

      assert_equal 0, op.time_input.utc_offset
      assert_equal 2023, op.time_input.year
      assert_equal 5, op.time_input.month
      assert_equal 5, op.time_input.day
      assert_equal 10, op.time_input.hour
      assert_equal 0, op.time_input.min
      assert_equal 30, op.time_input.sec
      assert_equal 0, op.time_input.usec

      op.time_input = '2023-05-05T10:00:30Z'
      assert_equal ::Time, op.time_input.class
      assert_equal 0, op.time_input.utc_offset
      assert_equal 2023, op.time_input.year
      assert_equal 5, op.time_input.month
      assert_equal 5, op.time_input.day
      assert_equal 10, op.time_input.hour
      assert_equal 0, op.time_input.min
      assert_equal 30, op.time_input.sec
      assert_equal 0, op.time_input.usec

      op.time_input = '2024-11-11T16:42:23.246+0100'
      assert_equal ::Time, op.time_input.class
      assert_equal 3600, op.time_input.utc_offset
      assert_equal 2024, op.time_input.year
      assert_equal 11, op.time_input.month
      assert_equal 11, op.time_input.day
      assert_equal 16, op.time_input.hour
      assert_equal 42, op.time_input.min
      assert_equal 23, op.time_input.sec
      assert_equal 0, op.time_input.usec

      time = Time.at(1678741605.123456).utc
      op.time_input = time
      refute_equal time, op.time_input
      refute_equal time.object_id, op.time_input.object_id
      assert_equal 2023, op.time_input.year
      assert_equal 3, op.time_input.month
      assert_equal 13, op.time_input.day
      assert_equal 21, op.time_input.hour
      assert_equal 6, op.time_input.min
      assert_equal 45, op.time_input.sec
      assert_equal 0, op.time_input.usec
    end

    def test_time_inputs__with_high_precision
      op.precise_time_input = nil
      assert_nil op.precise_time_input

      op.precise_time_input = '2022-12-22'
      assert_equal ::Time, op.precise_time_input.class
      refute_equal ::DateTime, op.precise_time_input.class

      assert_equal 2022, op.precise_time_input.year
      assert_equal 12, op.precise_time_input.month
      assert_equal 22, op.precise_time_input.day
      assert_equal 0, op.precise_time_input.hour
      assert_equal 0, op.precise_time_input.min
      assert_equal 0, op.precise_time_input.sec

      op.precise_time_input = ::DateTime.new(2022, 12, 22)
      assert_equal ::Time, op.precise_time_input.class
      refute_equal ::DateTime, op.precise_time_input.class

      assert_equal 0, op.precise_time_input.utc_offset
      assert_equal 2022, op.precise_time_input.year
      assert_equal 12, op.precise_time_input.month
      assert_equal 22, op.precise_time_input.day
      assert_equal 0, op.precise_time_input.hour
      assert_equal 0, op.precise_time_input.min
      assert_equal 0, op.precise_time_input.sec

      op.precise_time_input = '2023-05-05T10:00:30.123456Z'
      assert_equal ::Time, op.precise_time_input.class
      refute_equal ::DateTime, op.precise_time_input.class

      assert_equal 0, op.precise_time_input.utc_offset
      assert_equal 2023, op.precise_time_input.year
      assert_equal 5, op.precise_time_input.month
      assert_equal 5, op.precise_time_input.day
      assert_equal 10, op.precise_time_input.hour
      assert_equal 0, op.precise_time_input.min
      assert_equal 30, op.precise_time_input.sec
      assert_equal 123456, op.precise_time_input.usec

      op.precise_time_input = '2023-05-05T10:00:30Z'
      assert_equal ::Time, op.precise_time_input.class
      assert_equal 0, op.precise_time_input.utc_offset
      assert_equal 2023, op.precise_time_input.year
      assert_equal 5, op.precise_time_input.month
      assert_equal 5, op.precise_time_input.day
      assert_equal 10, op.precise_time_input.hour
      assert_equal 0, op.precise_time_input.min
      assert_equal 30, op.precise_time_input.sec
      assert_equal 0, op.precise_time_input.usec

      op.precise_time_input = '2024-11-11T16:42:23.246+0100'
      assert_equal ::Time, op.precise_time_input.class
      assert_equal 3600, op.precise_time_input.utc_offset
      assert_equal 2024, op.precise_time_input.year
      assert_equal 11, op.precise_time_input.month
      assert_equal 11, op.precise_time_input.day
      assert_equal 16, op.precise_time_input.hour
      assert_equal 42, op.precise_time_input.min
      assert_equal 23, op.precise_time_input.sec
      assert_equal 246000, op.precise_time_input.usec

      time = Time.at(1678741605.123456).utc
      op.precise_time_input = time
      assert_equal time, op.precise_time_input
      assert_equal time.object_id, op.precise_time_input.object_id
      assert_equal 2023, op.precise_time_input.year
      assert_equal 3, op.precise_time_input.month
      assert_equal 13, op.precise_time_input.day
      assert_equal 21, op.precise_time_input.hour
      assert_equal 6, op.precise_time_input.min
      assert_equal 45, op.precise_time_input.sec
      assert_equal 123456, op.precise_time_input.usec
    end

    def test_iso_date_inputs
      op.iso_date_input = nil
      assert_nil op.iso_date_input

      op.iso_date_input = '2022-12-22'
      assert_equal ::String, op.iso_date_input.class
      assert_equal '2022-12-22', op.iso_date_input

      op.iso_date_input = Date.parse('2022-12-22')
      assert_equal ::String, op.iso_date_input.class
      assert_equal '2022-12-22', op.iso_date_input
    end

    def test_iso_time_inputs
      op.iso_time_input = nil
      assert_nil op.iso_time_input

      op.iso_time_input = '2022-12-22T10:30:24Z'
      assert_equal ::String, op.iso_time_input.class
      assert_equal '2022-12-22T10:30:24.000Z', op.iso_time_input

      op.iso_time_input = Time.parse('2022-12-22T10:30:24.123456Z')
      assert_equal ::String, op.iso_time_input.class
      assert_equal '2022-12-22T10:30:24.123Z', op.iso_time_input
    end

    def test_file_inputs
      op.file_input = nil
      assert_nil op.file_input

      op.file_input = File.new(__FILE__)
      assert_equal ::File, op.file_input.class

      op.file_input = 'foobarbaz'
      assert_equal ::Tempfile, op.file_input.class
      assert_equal 'foobarbaz', op.file_input.read
    ensure
      op.file_input.close
      op.file_input.unlink
    end

    def test_when_a_type_cast_fails_a_type_cast_error_is_raised
      assert_raises Subroutine::TypeCaster::TypeCastError do
        op.date_input = "2015-13-01"
      end

      assert_raises "invalid date" do
        op.date_input = "2015-13-01"
      end
    end

    def test_foreign_key_inputs
      op.fk_input_owner_id = nil
      assert_nil op.fk_input_owner_id

      op.fk_input_owner_id = ""
      assert_nil op.fk_input_owner_id

      op.fk_input_owner_id = "19402"
      assert_equal 19402, op.fk_input_owner_id

      op.fk_input_owner_id = "19402.0"
      assert_equal 19402, op.fk_input_owner_id

      op.fk_input_email_address = nil
      assert_nil op.fk_input_email_address

      op.fk_input_email_address = ""
      assert_nil op.fk_input_email_address

      op.fk_input_email_address = "foo@bar.com"
      assert_equal "foo@bar.com", op.fk_input_email_address
    end
  end
end
