module Subroutine
  class UnknownOutputError < StandardError
    def initialize(name)
      super("Unknown output '#{name}'")
    end
  end

end
