require 'expeditor'

service = Expeditor::Service.new

i = 1
loop do
  puts '=' * 100
  p i

  command = Expeditor::Command.new(service: service, timeout: 1) {
    sleep 0.001 # simulate remote resource access
    if File.exist?('foo')
      'result'
    else
      raise 'Demo error'
    end
  }.set_fallback { |e|
    p e
    'default value'
  }.start

  p command.get
  p service.status
  puts

  i += 1
end
