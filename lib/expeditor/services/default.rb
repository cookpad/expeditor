require 'concurrent/configuration'
require 'expeditor/service'

module Expeditor
  module Services
    class Default < Expeditor::Service
      def initialize
        @executor = Concurrent.global_io_executor
        @bucket = nil
        @fallback_enabled = true
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

      def run_if_allowed
        yield
      end
    end
  end
end
