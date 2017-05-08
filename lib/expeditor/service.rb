require 'concurrent/executor/thread_pool_executor'

module Expeditor
  class Service
    attr_reader :executor
    attr_accessor :fallback_enabled

    def initialize(opts = {})
      @mutex = Mutex.new
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

    def breaking?
      @breaking
    end

    # Run given block when the request is allowed, otherwise raise
    # Expeditor::CircuitBreakError. When breaking and sleep time was passed,
    # the circuit breaker tries to close the circuit. So subsequent single
    # command execution is allowed (will not be breaked) to check the service
    # is healthy or not. The circuit breaker only allows one request so other
    # subsequent requests will be aborted with CircuitBreakError. When the test
    # request succeeds, the circuit breaker resets the service status and
    # closes the circuit.
    def run_if_allowed
      if @breaking
        now = Time.now

        # Only one thread can be allowed to execute single request when half-opened.
        allow_single_request = false
        @mutex.synchronize do
          allow_single_request = now - @break_start > @sleep
          @break_start = now if allow_single_request
        end

        if allow_single_request
          result = yield # This can be raise exception.
          # The execution succeed, then
          reset_status!
          result
        else
          raise CircuitBreakError
        end
      else
        open = calc_open
        if open
          change_state(true, Time.now)
          raise CircuitBreakError
        else
          yield
        end
      end
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
      @mutex.synchronize do
        @bucket = Expeditor::Bucket.new(@bucket_opts)
        @breaking = false
        @break_start = nil
      end
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

    def change_state(breaking, break_start)
      @mutex.synchronize do
        @breaking = breaking
        @break_start = break_start
      end
    end
  end
end
