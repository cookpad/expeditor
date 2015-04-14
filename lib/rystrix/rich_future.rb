require 'concurrent/configuration'
require 'concurrent/future'

module Rystrix
  class RichFuture < Concurrent::Future
    def get
      wait
      if rejected?
        raise reason
      else
        value
      end
    end

    def get_or_else(&block)
      wait
      if rejected?
        block.call
      else
        value
      end
    end

    def set(v)
      super(v)
    end

    def safe_set(v)
      set(v) unless completed?
    end

    def fail(e)
      super(e)
    end

    def safe_fail(e)
      fail(e) unless completed?
    end

    def executed?
      not unscheduled?
    end

    def safe_execute
      begin
        execute
      rescue Exception => e
        fail(e)
      end
    end

    private

    # This is workaround for concurrent-ruby's deadlock bug
    # see: ruby-concurrency/concurrent-ruby#275
    def work
      success, val, reason = Concurrent::SafeTaskExecutor.new(@task, rescue_exception: true).execute(*@args)
      complete(success, val, reason)
    end
  end
end
