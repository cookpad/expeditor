require 'rystrix'

start_time = Time.now

# Create new service (it is containing a thread pool and circuit breaker function)
service = Rystrix::Service.new(
  min_threads: 5,      # minimum number of threads
  max_threads: 5,      # maximum number of threads
  max_queue: 0,        # max size of task queue (including executing threads)
  non_break_count: 10, # max count of non break
  threshold: 0.5,      # failure rate to break (0.0 - 1.0)
)

# Create commands
command1 = Rystrix::Command.new(service: service) do
  sleep 0.1
  'command1'
end

command2 = Rystrix::Command.new(service: service, timeout: 0.5) do
  sleep 1000
  'command2'
end
# command2_d is command2 with fallback
command2_d = command2.with_fallback do |e|
  'command2 fallback'
end

command3 = Rystrix::Command.new(
  service: service,
  dependencies: [command1, command2_d]
) do |v1, v2|
  sleep 0.2
  v1 + ', ' + v2
end

command4 = Rystrix::Command.new(
  service: service,
  dependencies: [command2, command3],
  timeout: 1
) do |v2, v3|
  sleep 0.3
  v2 + ', ' + v3
end
command4_d = command4.with_fallback do
  'command4 fallback'
end

# Start command (all dependencies of command4_d are executed. this is non blocking)
command4_d.start

puts Time.now - start_time #=> 0.00...
puts command1.get          #=> command1
puts Time.now - start_time #=> 0.10...
puts command2_d.get        #=> command2 fallback
puts Time.now - start_time #=> 0.50...
puts command4_d.get        #=> command4 fallback
puts Time.now - start_time #=> 0.50...
puts command3.get          #=> command3
puts Time.now - start_time #=> 0.70...
