# frozen_string_literal: true

module Subroutine
  class OutputNotSetError < StandardError
    def initialize(name)
      super("Expected output '#{name}' to be set upon completion of perform but was not.")
    end
  end
end
