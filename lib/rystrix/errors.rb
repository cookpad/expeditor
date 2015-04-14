require 'concurrent/errors'

module Rystrix
  NotStartedError = Class.new(StandardError)
  TimeoutError = Concurrent::TimeoutError
  RejectedExecutionError = Concurrent::RejectedExecutionError
  CircuitBreakError = Class.new(StandardError)
end
