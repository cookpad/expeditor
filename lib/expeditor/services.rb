require 'concurrent/configuration'
require 'expeditor/services/default'

module Expeditor
  module Services
    DEFAULT_SERVICE = Expeditor::Services::Default.new
    private_constant :DEFAULT_SERVICE

    def default
      DEFAULT_SERVICE
    end
    module_function :default
  end
end
