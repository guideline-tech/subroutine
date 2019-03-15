# frozen_string_literal: true

module Subroutine
  class UnknownOutputError < StandardError
    def initialize(name)
      super("Unknown output '#{name}'")
    end
  end
end
