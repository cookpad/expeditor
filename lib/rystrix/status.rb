module Rystrix
  class Status
    attr_reader :success
    attr_reader :failure
    attr_reader :rejection
    attr_reader :timeout

    def initialize
      reset
    end

    def increment(type)
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

    def reset
      set(0, 0, 0, 0)
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
