require 'concurrent/configuration'
require 'rystrix/services/default'

module Rystrix
  module Services
    DEFAULT_SERVICE = Rystrix::Services::Default.new
    private_constant :DEFAULT_SERVICE

    def default
      DEFAULT_SERVICE
    end
    module_function :default
  end
end
