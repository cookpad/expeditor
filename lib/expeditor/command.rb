require 'concurrent/utility/timeout'
require 'concurrent/ivar'
require 'concurrent/executor/safe_task_executor'
require 'concurrent/configuration'
require 'expeditor/errors'
require 'expeditor/rich_future'
require 'expeditor/service'
require 'expeditor/services'
require 'retryable'

module Expeditor
  class Command
    def initialize(opts = {}, &block)
      @service = opts.fetch(:service, Expeditor::Services.default)
      @timeout = opts[:timeout]
      @dependencies = opts.fetch(:dependencies, [])
      @normal_future = initial_normal(&block)
      @fallback_var = nil
      @retryable_options = Concurrent::IVar.new
    end

    def start
      if not started?
        @dependencies.each(&:start)
        @normal_future.safe_execute
      end
      self
    end

    # Equivalent to retryable gem options
    def start_with_retry(retryable_options = {})
      if not started?
        @retryable_options.set(retryable_options)
        start
      end
      self
    end

    def started?
      @normal_future.executed?
    end

    def get
      raise NotStartedError if not started?
      @normal_future.get_or_else do
        if @fallback_var
          @fallback_var.wait
          if @fallback_var.rejected?
            raise @fallback_var.reason
          else
            @fallback_var.value
          end
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
      raise NotStartedError if not started?
      @normal_future.wait
      @fallback_var.wait if @fallback_var
    end

    # command.on_complete do |success, value, reason|
    #   ...
    # end
    def on_complete(&block)
      on do |_, value, reason|
        block.call(reason == nil, value, reason)
      end
    end

    # command.on_success do |value|
    #   ...
    # end
    def on_success(&block)
      on do |_, value, reason|
        block.call(value) unless reason
      end
    end

    # command.on_failure do |e|
    #   ...
    # end
    def on_failure(&block)
      on do |_, _, reason|
        block.call(reason) if reason
      end
    end

    # `chain` returns new command that has self as dependencies
    def chain(opts = {}, &block)
      opts[:dependencies] = [self]
      Command.new(opts, &block)
    end

    def self.const(value)
      ConstCommand.new(value)
    end

    def self.start(opts = {}, &block)
      Command.new(opts, &block).start
    end

    protected

    def reset_fallback(&block)
      @fallback_var = Concurrent::IVar.new
      @normal_future.add_observer do |_, value, reason|
        if reason != nil
          future = RichFuture.new(executor: Concurrent.configuration.global_task_pool) do
            success, val, reason = Concurrent::SafeTaskExecutor.new(block, rescue_exception: true).execute(reason)
            @fallback_var.complete(success, val, reason)
          end
          future.safe_execute
        else
          @fallback_var.complete(true, value, nil)
        end
      end
    end

    private

    def breakable_block(args, &block)
      if @service.open?
        raise CircuitBreakError
      else
        block.call(*args)
      end
    end

    def retryable_block(args, &block)
      if @retryable_options.fulfilled?
        Retryable.retryable(@retryable_options.value) do |retries, exception|
          metrics(exception) if retries > 0
          breakable_block(args, &block)
        end
      else
        breakable_block(args, &block)
      end
    end

    def timeout_block(args, &block)
      if @timeout
        Concurrent::timeout(@timeout) do
          retryable_block(args, &block)
        end
      else
        retryable_block(args, &block)
      end
    end

    def metrics(reason)
      case reason
      when nil
        @service.success
      when TimeoutError
        @service.timeout
      when RejectedExecutionError
        @service.rejection
      when CircuitBreakError
        @service.break
      when DependencyError
        @service.dependency
      else
        @service.failure
      end
    end

    # timeout do
    #   retryable do
    #     circuit break do
    #       block.call
    #     end
    #   end
    # end
    def initial_normal(&block)
      future = RichFuture.new(executor: @service.executor) do
        args = wait_dependencies
        timeout_block(args, &block)
      end
      future.add_observer do |_, _, reason|
        metrics(reason)
      end
      future
    end

    def wait_dependencies
      if @dependencies.count > 0
        current = Thread.current
        executor = Concurrent::ThreadPoolExecutor.new(
          min_threads: 0,
          max_threads: 5,
          max_queue: 0,
        )
        error = Concurrent::IVar.new
        error.add_observer do |_, e, _|
          executor.shutdown
          current.raise(DependencyError.new(e))
        end
        args = []
        @dependencies.each_with_index do |c, i|
          executor.post do
            begin
              args[i] = c.get
            rescue => e
              error.set(e)
            end
          end
        end
        executor.shutdown
        executor.wait_for_termination
        args
      else
        []
      end
    end

    def on(&callback)
      if @fallback_var
        @fallback_var.add_observer(&callback)
      else
        @normal_future.add_observer(&callback)
      end
    end

    class ConstCommand < Command
      def initialize(value)
        @service = Expeditor::Services.default
        @dependencies = []
        @normal_future = RichFuture.new {}.set(value)
      end
    end
  end
end
