require 'concurrent/errors'

module Rystrix
  NotExecutedError = Class.new(StandardError)
  TimeoutError = Concurrent::TimeoutError
end
