require 'rystrix/rich_future'

module Rystrix
  class Command
    def initialize(opts = {}, &block)
      @future = RichFuture.new(&block)
    end

    def execute
      @future.execute
    end
  end
end
