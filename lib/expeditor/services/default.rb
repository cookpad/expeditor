require 'concurrent/configuration'
require 'expeditor/service'

module Expeditor
  module Services
    class Default < Expeditor::Service
      def initialize
        @executor = Concurrent.global_io_executor
        @bucket = nil
      end

      def success
      end

      def failure
      end

      def rejection
      end

      def timeout
      end

      def break
      end

      def dependency
      end

      def open?
        false
      end
    end
  end
end
