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
