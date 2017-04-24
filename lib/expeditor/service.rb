require 'concurrent/executor/thread_pool_executor'

module Expeditor
  class Service
    attr_reader :executor
    attr_accessor :fallback_enabled

    def initialize(opts = {})
      @executor = opts.fetch(:executor) { Concurrent::ThreadPoolExecutor.new }
      @threshold = opts.fetch(:threshold, 0.5)
      @non_break_count = opts.fetch(:non_break_count, 20)
      @sleep = opts.fetch(:sleep, 1)
      @bucket_opts = {
        size: 10,
        per: opts.fetch(:period, 10).to_f / 10
      }
      reset_status!
      @fallback_enabled = true
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

    def fallback_enabled?
      !!fallback_enabled
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

    def status
      @bucket.total
    end

    # @deprecated
    def current_status
      warn 'Expeditor::Service#current_status is deprecated. Please use #status instead'
      @bucket.current
    end

    def reset_status!
      @bucket = Expeditor::Bucket.new(@bucket_opts)
      @breaking = false
      @break_start = nil
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
