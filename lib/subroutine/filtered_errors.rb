# frozen_string_literal: true

module Subroutine
  class FilteredErrors < SimpleDelegator
    def add(*args)
      return if __getobj__.instance_variable_get('@base')._error_ignores[args[0].to_sym]

      __getobj__.add(*args)
    end
  end
end
