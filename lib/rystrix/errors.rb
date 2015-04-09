require 'concurrent/errors'

module Rystrix
  NotExecutedYetError = Class.new(StandardError)
  TimeoutError = Concurrent::TimeoutError
end
