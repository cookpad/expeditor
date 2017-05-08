module Expeditor
  # Circular buffer with user-defined initialization and optimized `move`
  # implementation.
  #
  # Thread unsafe.
  class RingBuffer
    # @params [Integer] size
    def initialize(size, &initialize_proc)
      raise ArgumentError.new('initialize_proc is not given') unless initialize_proc
      @size = size
      @initialize_proc = initialize_proc
      @elements = Array.new(@size, &initialize_proc)
      @current_index = 0
    end

    # @return [Object] user created object with given initialization proc.
    def current
      @elements[@current_index]
    end

    # @params [Integer] times How many elements will we pass.
    # @return [Object] current element after moving.
    def move(times)
      cut_moving_time_if_possible(times).times do
        next_element
      end
    end

    # @return [Array<Object>] Array of elements.
    def all
      @elements
    end

    private

    # This logic is used for cutting moving times. When moving times is greater
    # than statuses size, we can cut moving times to less than statuses size
    # because the statuses are circulated.
    #
    # `*` is current index.
    # When the statuses size is 3:
    #
    #   [*, , ]
    #
    # Then when the moving times = 3, current index will be 0 (0-origin):
    #
    #   [*, , ] -3> [ ,*, ] -2> [ , ,*] -1> [*, , ]
    #
    # Then moving times = 6, current index will be 0 again:
    #
    #   [*, , ] -6> [ ,*, ] -5> [ , ,*] -4> [*, , ] -3> [ ,*, ] -2> [ , ,*] -1> [*, , ]
    #
    # In that case we can cut the moving times from 6 to 3.
    # That is "cut moving times" here.
    #
    # TODO: We can write more optimized code which resets all elements with
    # Array.new if given moving times is greater than `@size`.
    def cut_moving_time_if_possible(times)
      if times >= @size * 2
        (times % @size) + @size
      else
        times
      end
    end

    # Move and initialize
    def next_element
      if @current_index == @size - 1
        @current_index = 0
      else
        @current_index += 1
      end
      initialize_current_element
    end

    def initialize_current_element
      @elements[@current_index] = @initialize_proc.call
    end
  end
end
