require 'concurrent/configuration'
require 'rystrix/service'

module Rystrix
  module Services
    class Default < Rystrix::Service
      def initialize
        @executor = Concurrent.configuration.global_task_pool
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
    end
  end
end
