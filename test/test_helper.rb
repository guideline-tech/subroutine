# frozen_string_literal: true

require "subroutine"
require "minitest/autorun"
require "minitest/unit" if Minitest::VERSION.to_i < 6

require "minitest/reporters"
require "mocha/minitest"

require "byebug"
require "action_controller"

Minitest::Reporters.use!([Minitest::Reporters::DefaultReporter.new])

class TestCase < ::Minitest::Test; end

require_relative "support/ops"
