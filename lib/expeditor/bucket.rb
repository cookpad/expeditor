require 'expeditor/status'

module Expeditor
  # Bucket is a data structure like circular buffer. It holds some status
  # objects and it rolls statuses each `per` time (default is 1 second). Once
  # it reaches the end of statuses array, it backs to start of statuses array
  # and then reset the status and resumes recording. This is done so that the
  # statistics are recorded gradually with short time interval rahter than
  # reset all the record every wide time range (default is 10 seconds).
  class Bucket
    def initialize(opts = {})
      @mutex = Mutex.new
      @current_index = 0
      @size = opts.fetch(:size, 10)
      @per_time = opts.fetch(:per, 1)
      @current_start = Time.now
      @statuses = [].fill(0..(@size - 1)) do
        Expeditor::Status.new
      end
    end

    def increment(type)
      @mutex.synchronize do
        update
        @statuses[@current_index].increment type
      end
    end

    def total
      acc = @mutex.synchronize do
        update
        @statuses.inject([0, 0, 0, 0, 0, 0]) do |i, s|
          i[0] += s.success
          i[1] += s.failure
          i[2] += s.rejection
          i[3] += s.timeout
          i[4] += s.break
          i[5] += s.dependency
          i
        end
      end
      status = Expeditor::Status.new
      status.success = acc[0]
      status.failure = acc[1]
      status.rejection = acc[2]
      status.timeout = acc[3]
      status.break = acc[4]
      status.dependency = acc[5]
      status
    end

    def current
      @mutex.synchronize do
        update
        @statuses[@current_index]
      end
    end

    private

    def update
      passing = last_passing
      if passing > 0
        @current_start = @current_start + @per_time * passing
        cut_passing_size_if_possible(passing, @size).times do
          @current_index = next_index
          @statuses[@current_index].reset
        end
      end
    end

    # This logic is used for cutting passing size. When passing size is greater
    # than buckets size, we can cut passing size to less than bucket size
    # because the buckets are circulated.
    #
    # `*` is current position.
    # When the bucket size is 3:
    #
    #   [*, , ]
    #
    # Then when the passing = 3, position will be 0 (0-origin):
    #
    #   [*, , ] -3> [ ,*, ] -2> [ , ,*] -1> [*, , ]
    #
    # Then passing = 6, position will be 0 again:
    #
    #   [*, , ] -6> [ ,*, ] -5> [ , ,*] -4> [*, , ] -3> [ ,*, ] -2> [ , ,*] -1> [*, , ]
    #
    # In that case we can cut the passing size from 6 to 3.
    # That is "cut passing size" here.
    def cut_passing_size_if_possible(passing, size)
      if passing >= size * 2
        (passing % size) + size
      else
        passing
      end
    end

    def last_passing
      (Time.now - @current_start).div @per_time
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
