module Rystrix
  class Status
    def initialize
      @mutex = Mutex.new
      set(0, 0, 0, 0)
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
      set(0, 0, 0, 0)
    end

    def success
      @mutex.synchronize { @success }
    end

    def success=(n)
      @mutex.synchronize do
        @success = n
      end
    end

    def failure
      @mutex.synchronize { @failure }
    end

    def failure=(n)
      @mutex.synchronize do
        @failure = n
      end
    end

    def rejection
      @mutex.synchronize { @rejection }
    end

    def rejection=(n)
      @mutex.synchronize do
        @rejection = n
      end
    end

    def timeout
      @mutex.synchronize { @timeout }
    end

    def timeout=(n)
      @mutex.synchronize do
        @timeout = n
      end
    end

    private

    def set(s, f, r, t)
      @mutex.synchronize do
        @success = s
        @failure = f
        @rejection = r
        @timeout = t
      end
    end
  end
end
