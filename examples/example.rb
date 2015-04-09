require 'rystrix'

start_time = Time.now

service = Rystrix::Service.new

command1 = Rystrix::Command.new(service: service) do
  sleep 0.1
  'command1'
end

command2 = Rystrix::Command.new(service: service, timeout: 0.5) do
  sleep 1000
  'command2'
end
command2_d = command2.with_fallback do |e|
  'command2 fallback'
end

command3 = Rystrix::Command.new(service: service, args: [command1, command2_d]) do |v1, v2|
  sleep 0.2
  v1 + ', ' + v2
end

command4 = Rystrix::Command.new(service: service, args: [command2, command3], timeout: 1) do |v2, v3|
  sleep 0.3
  v2 + ', ' + v3
end
command4_d = command4.with_fallback do
  'command4 fallback'
end

command4_d.execute

puts Time.now - start_time
puts command1.get
puts Time.now - start_time
puts command2_d.get
puts Time.now - start_time
puts command4_d.get
puts Time.now - start_time
puts command3.get
puts Time.now - start_time
