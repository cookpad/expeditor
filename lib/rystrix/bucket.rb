require 'rystrix/status'

module Rystrix
  class Bucket
    def initialize(opts = {})
      @current_index = 0
      @size = opts.fetch(:size, 10)
      @par_time = opts.fetch(:par, 1)
      @current_start = Time.now
      array = []
      @statuses = array.fill(0..(@size - 1)) do
        Rystrix::Status.new
      end
    end

    def increment(type)
      current.increment type
    end

    def total
      update
      acc = @statuses.inject([0, 0, 0, 0]) do |acc, s|
        acc[0] += s.success
        acc[1] += s.failure
        acc[2] += s.rejection
        acc[3] += s.timeout
        acc
      end
      status = Rystrix::Status.new
      status.success = acc[0]
      status.failure = acc[1]
      status.rejection = acc[2]
      status.timeout = acc[3]
      status
    end

    def current
      update
      @statuses[@current_index]
    end

    private

    def update
      passing = (Time.now - @current_start).div @par_time
      if passing > 0
        @current_start = @current_start + @par_time * passing
        passing.times do
          @current_index = next_index
          @statuses[@current_index].reset
        end
      end
    end

    def next_index
      if @current_index == @size - 1
        0
      else
        @current_index + 1
      end
    end
  end
end
