require 'concurrent/executor/thread_pool_executor'

module Expeditor
  class Service
    attr_reader :executor

    def initialize(opts = {})
      @executor = opts.fetch(:executor) { Concurrent::ThreadPoolExecutor.new }
      @threshold = opts.fetch(:threshold, 0.5) # is 0.5 ok?
      @non_break_count = opts.fetch(:non_break_count, 100) # is 100 ok?
      @sleep = opts.fetch(:sleep, 1)
      bucket_opts = {
        size: 10,
        per: opts.fetch(:period, 10).to_f / 10
      }
      @bucket = Expeditor::Bucket.new(bucket_opts)
      @breaking = false
      @break_start = nil
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

    def dependency
      @bucket.increment :dependency
    end

    # break circuit?
    def open?
      if @breaking
        if Time.now - @break_start > @sleep
          @breaking = false
          @break_start = nil
        else
          return true
        end
      end
      open = calc_open
      if open
        @breaking = true
        @break_start = Time.now
      end
      open
    end

    # shutdown thread pool
    # after shutdown, if you create thread, RejectedExecutionError is raised.
    def shutdown
      @executor.shutdown
    end

    def current_status
      @bucket.current
    end

    private

    def calc_open
      s = @bucket.total
      total_count = s.success + s.failure + s.timeout
      if total_count >= [@non_break_count, 1].max
        failure_count = s.failure + s.timeout
        failure_count.to_f / total_count.to_f >= @threshold
      else
        false
      end
    end
  end
end
