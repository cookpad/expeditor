require 'concurrent/executor/thread_pool_executor'

module Rystrix
  class Service
    attr :executor

    def initialize(opts = {})
      @executor = Concurrent::ThreadPoolExecutor.new(opts)
      @bucket = Rystrix::Bucket.new(opts)
      @threshold = opts.fetch(:threshold, 0.5) # is 0.5 ok?
      @non_break_count = opts.fetch(:non_break_count, 100) # is 100 ok?
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

    def break
      @bucket.increment :break
    end

    # break circuit?
    def open?
      s = @bucket.total
      total_count = s.success + s.failure + s.rejection + s.timeout
      if total_count > [@non_break_count, 0].max
        failure_count = s.failure + s.timeout # also rejection?
        failure_count.to_f / total_count.to_f >= @threshold
      else
        false
      end
    end

    # shutdown thread pool
    # after shutdown, if you create thread, RejectedExecutionError is raised.
    def shutdown
      @executor.shutdown
    end
  end
end
