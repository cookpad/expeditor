require 'concurrent/executor/thread_pool_executor'

module Rystrix
  class Service
    attr :executor

    def initialize(opts = {})
      @executor = Concurrent::ThreadPoolExecutor.new(opts)
    end
  end
end
