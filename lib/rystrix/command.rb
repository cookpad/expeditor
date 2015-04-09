require 'concurrent/utility/timeout'
require 'rystrix/errors'
require 'rystrix/rich_future'

module Rystrix
  class Command
    def initialize(opts = {}, &block)
      @timeout = opts[:timeout]
      @args = opts.fetch(:args, [])
      @normal_future = initial_normal(&block)
      @fallback_future = nil
    end

    def execute
      @normal_future.execute
      if @fallback_future
        @fallback_future.execute
      end
      self
    end

    def executed?
      @normal_future.executed? and
        if @fallback_future then @fallback_future.executed? else true end
    end

    def get
      raise NotExecutedYetError if not @normal_future.executed?
      @normal_future.get
    end

    def with_fallback(&block)
      command = self.clone
      command.reset_fallback(&block)
      command
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
      RichFuture.new do
        args = run_args
        if @timeout
          Concurrent::timeout(@timeout) do
            block.call(*args)
          end
        else
          block.call(*args)
        end
      end
    end

    def run_args
      @args.each(&:execute)
      @args.map(&:get)
    end
  end
end
