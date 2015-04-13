require 'concurrent/errors'

module Rystrix
  NotExecutedError = Class.new(StandardError)
  TimeoutError = Concurrent::TimeoutError
  RejectedExecutionError = Concurrent::RejectedExecutionError
  CircuitBreakError = Class.new(StandardError)
end
