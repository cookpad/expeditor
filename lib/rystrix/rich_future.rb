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
  end
end
