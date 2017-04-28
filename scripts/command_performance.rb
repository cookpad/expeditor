$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'expeditor'

require 'benchmark/ips'

Benchmark.ips do |x|
  x.report("simple command") do |i|
    executor = Concurrent::ThreadPoolExecutor.new(min_threads: 100, max_threads: 100, max_queue: 100)
    service = Expeditor::Service.new(period: 10, non_break_count: 0, threshold: 0.5, sleep: 1, executor: executor)

    i.times do
      commands = 10000.times.map do
        Expeditor::Command.new { 1 }.start
      end
      command = Expeditor::Command.new(service: service, dependencies: commands) do |*vs|
        vs.inject(0, &:+)
      end.start
      command.get

      service.reset_status!
    end
  end

  x.compare!
end
