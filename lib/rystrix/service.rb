require 'concurrent/executor/thread_pool_executor'

module Rystrix
  class Service
    attr :executor

    def initialize(opts = {})
      @executor = Concurrent::ThreadPoolExecutor.new(opts)
      @bucket = Rystrix::Bucket.new(opts)
    end

    def success
      @bucket.increment :success
    end

    def failure
      @bucket.increment :failure
    end

    def rejection
      @bucket.increment :rejection
    end

    def timeout
      @bucket.increment :timeout
    end
  end
end
