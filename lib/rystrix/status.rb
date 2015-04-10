module Rystrix
  class Status
    attr_reader :success
    attr_reader :failure
    attr_reader :rejection
    attr_reader :timeout

    def initialize
      set(0, 0, 0, 0)
      @mutex = Mutex.new
    end

    def increment(type)
      @mutex.synchronize do
        case type
        when :success
          @success += 1
        when :failure
          @failure += 1
        when :rejection
          @rejection += 1
        when :timeout
          @timeout += 1
        else
        end
      end
    end

    def reset
      @mutex.synchronize do
        set(0, 0, 0, 0)
      end
    end

    protected

    def set(s, f, r, t)
      @success = s
      @failure = f
      @rejection = r
      @timeout = t
    end
  end
end
