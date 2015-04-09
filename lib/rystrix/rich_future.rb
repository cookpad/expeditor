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

    def fail(e)
      super(e)
    end
  end
end
