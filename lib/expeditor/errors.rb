require 'concurrent/errors'

module Expeditor
  NotStartedError = Class.new(StandardError)
  RejectedExecutionError = Concurrent::RejectedExecutionError
  CircuitBreakError = Class.new(StandardError)
  class DependencyError < StandardError
    attr :error
    def initialize(e)
      @error = e
    end
  end
end
