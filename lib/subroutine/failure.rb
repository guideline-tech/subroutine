# frozen_string_literal: true

module Subroutine
  class Failure < StandardError
    attr_reader :record
    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(', ')
      super(errors)
    end
  end
end
