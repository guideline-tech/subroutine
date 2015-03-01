require 'subroutine'
require 'minitest/autorun'
require 'minitest/unit'

require 'minitest/reporters'

Minitest::Reporters.use!([Minitest::Reporters::DefaultReporter.new])

class TestCase < (MiniTest::TestCase rescue ::MiniTest::Test); end

require_relative 'support/ops'


