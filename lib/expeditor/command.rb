require 'concurrent/ivar'
require 'concurrent/executor/safe_task_executor'
require 'concurrent/configuration'
require 'expeditor/errors'
require 'expeditor/rich_future'
require 'expeditor/service'
require 'expeditor/services'
require 'retryable'
require 'timeout'

module Expeditor
  class Command
    def initialize(opts = {}, &block)
      @service = opts.fetch(:service, Expeditor::Services.default)
      @timeout = opts[:timeout]
      @dependencies = opts.fetch(:dependencies, [])

      @normal_future = nil
      @retryable_options = Concurrent::IVar.new
      @normal_block = block
      @fallback_block = nil
      @ivar = Concurrent::IVar.new
    end

    # @param current_thread [Boolean] Execute the task on current thread(blocking)
    def start(current_thread: false)
      unless started?
        if current_thread
          prepare(Concurrent::ImmediateExecutor.new)
        else
          prepare
        end
        @normal_future.safe_execute
      end
      self
    end

    # Equivalent to retryable gem options
    def start_with_retry(current_thread: false, **retryable_options)
      unless started?
        @retryable_options.set(retryable_options)
        start(current_thread: current_thread)
      end
      self
    end

    def started?
      @normal_future && @normal_future.executed?
    end

    def get
      raise NotStartedError unless started?
      @normal_future.get_or_else do
        if @fallback_block && @service.fallback_enabled?
          @ivar.wait
          if @ivar.rejected?
            raise @ivar.reason
          else
            @ivar.value
          end
        else
          raise @normal_future.reason
        end
      end
    end

    def set_fallback(&block)
      if started?
        raise AlreadyStartedError, "Do not allow set_fallback call after command is started"
      end
      reset_fallback(&block)
      self
    end

    def with_fallback(&block)
      warn 'Expeditor::Command#with_fallback is deprecated. Please use set_fallback instead'
      set_fallback(&block)
    end

    def wait
      raise NotStartedError unless started?
      @ivar.wait
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

    # XXX: Raise ArgumentError when given `opts` has :dependencies
    # because this forcefully change given :dependencies.
    #
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

    private

    # set future
    # set fallback future as an observer
    # start dependencies
    def prepare(executor = @service.executor)
      @normal_future = initial_normal(executor, &@normal_block)
      @normal_future.add_observer do |_, value, reason|
        if reason # failure
          if @fallback_block
            future = RichFuture.new(executor: executor) do
              success, value, reason = Concurrent::SafeTaskExecutor.new(@fallback_block, rescue_exception: true).execute(reason)
              if success
                @ivar.set(value)
              else
                @ivar.fail(reason)
              end
            end
            future.safe_execute
          else
            @ivar.fail(reason)
          end
        else # success
          @ivar.set(value)
        end
      end

      @dependencies.each(&:start)
    end

    # timeout_block do
    #   retryable_block do
    #     breakable_block do
    #       block.call
    #     end
    #   end
    # end
    def initial_normal(executor, &block)
      future = RichFuture.new(executor: executor) do
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

    def timeout_block(args, &block)
      if @timeout
        Timeout::timeout(@timeout) do
          retryable_block(args, &block)
        end
      else
        retryable_block(args, &block)
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

    def breakable_block(args, &block)
      @service.run_if_allowed do
        block.call(*args)
      end
    end

    def metrics(reason)
      case reason
      when nil
        @service.success
      when Timeout::Error
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

    def reset_fallback(&block)
      @fallback_block = block
    end

    def on(&callback)
      @ivar.add_observer(&callback)
    end

    class ConstCommand < Command
      def initialize(value)
        super(){ value }
        self.start
      end
    end
  end
end
