# frozen_string_literal: true

require 'subroutine'
require 'minitest/autorun'
require 'minitest/unit'

require 'minitest/reporters'
require 'mocha/minitest'

Minitest::Reporters.use!([Minitest::Reporters::DefaultReporter.new])

class TestCase < ::Minitest::Test; end

require_relative 'support/ops'
