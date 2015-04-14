require 'concurrent/errors'

module Rystrix
  NotStartedError = Class.new(StandardError)
  TimeoutError = Concurrent::TimeoutError
  RejectedExecutionError = Concurrent::RejectedExecutionError
  CircuitBreakError = Class.new(StandardError)
  class DependencyError < StandardError
    attr :error
    def initialize(e)
      @error = e
    end
  end
end
