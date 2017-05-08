module Expeditor
  class Status
    attr_reader :success
    attr_reader :failure
    attr_reader :rejection
    attr_reader :timeout
    attr_reader :break
    attr_reader :dependency

    def initialize
      set(0, 0, 0, 0, 0, 0)
    end

    def increment(type, i = 1)
      case type
      when :success
        @success += i
      when :failure
        @failure += i
      when :rejection
        @rejection += i
      when :timeout
        @timeout += i
      when :break
        @break += i
      when :dependency
        @dependency += i
      else
        raise ArgumentError.new("Unknown type: #{type}")
      end
    end

    def merge!(other)
      increment(:success, other.success)
      increment(:failure, other.failure)
      increment(:rejection, other.rejection)
      increment(:timeout, other.timeout)
      increment(:break, other.break)
      increment(:dependency, other.dependency)
      self
    end

    def reset
      set(0, 0, 0, 0, 0, 0)
    end

    private

    def set(s, f, r, t, b, d)
      @success = s
      @failure = f
      @rejection = r
      @timeout = t
      @break = b
      @dependency = d
    end
  end
end
