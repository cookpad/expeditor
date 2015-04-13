require 'concurrent/utility/timeout'
require 'rystrix/errors'
require 'rystrix/rich_future'
require 'rystrix/service'
require 'rystrix/services'

module Rystrix
  class Command
    def initialize(opts = {}, &block)
      @service = opts.fetch(:service, Rystrix::Services.default)
      @timeout = opts[:timeout]
      @args = opts.fetch(:args, [])
      @normal_future = initial_normal(&block)
      @fallback_future = nil
    end

    def execute
      @args.each(&:execute)
      if @service.open?
        @normal_future.fail(Rystrix::CircuitBreakError)
      else
        @normal_future.safe_execute
      end
      @fallback_future.safe_execute if @fallback_future
      self
    end

    def executed?
      @normal_future.executed? and
        if @fallback_future then @fallback_future.executed? else true end
    end

    def get
      raise NotExecutedError if not executed?
      @normal_future.get_or_else do
        if @fallback_future
          @fallback_future.get
        else
          raise @normal_future.reason
        end
      end
    end

    def with_fallback(&block)
      command = self.clone
      command.reset_fallback(&block)
      command
    end

    def wait
      raise NotExecutedError if not executed?
      @normal_future.wait
      @fallback_future.wait if @fallback_future
    end

    protected

    def reset_fallback(&block)
      @fallback_future = RichFuture.new do
        @normal_future.wait
        if @normal_future.rejected?
          block.call(@normal_future.reason)
        end
      end
    end

    private

    def initial_normal(&block)
      future = RichFuture.new(executor: @service.executor) do
        args = wait_args
        if @timeout
          Concurrent::timeout(@timeout) do
            block.call(*args)
          end
        else
          block.call(*args)
        end
      end
      future.add_observer do |_, _, reason|
        case reason
        when nil
          @service.success
        when TimeoutError
          @service.timeout
        when RejectedExecutionError
          @service.rejection
        else
          @service.failure
        end
      end
      future
    end

    def wait_args
      current = Thread.current
      executor = Concurrent::ThreadPoolExecutor.new(
        min_threads: 0,
        max_threads: 5,
        max_queue: 0,
      )
      args = []
      @args.each_with_index do |c, i|
        executor.post do
          begin
            args[i] = c.get
          rescue => e
            current.raise(e)
          end
        end
      end
      executor.shutdown
      executor.wait_for_termination
      args
    end
  end
end
