require 'spec_helper'

describe Expeditor::Command do
  describe 'circuit break function' do
    context 'with circuit break' do
      it 'should reject execution' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_queue: 0), threshold: 0.5, non_break_count: 100, sleep: 0, period: 10)
        commands = 100.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end.set_fallback do |e|
            if e === Expeditor::CircuitBreakError
              1
            else
              0
            end
          end
        end
        commands.each(&:start)
        sum = commands.map(&:get).inject(:+)
        expect(sum).to eq(0)
        command = Expeditor::Command.new(service: service) do
          42
        end
        command.start
        expect { command.get }.to raise_error(Expeditor::CircuitBreakError)
        service.shutdown
      end

      it 'should not count circuit break' do
        service = Expeditor::Service.new(threshold: 0, non_break_count: 0)
        commands = 100.times.map do
          Expeditor::Command.new(service: service) do
            raise Expeditor::CircuitBreakError
          end
        end
        commands.map(&:start)
        commands.map(&:wait)
        command = Expeditor::Command.new(service: service) do
          42
        end
        command.start
        expect(command.get).to eq(42)
        service.shutdown
      end
    end

    context 'with circuit break and wait' do
      it 'should reject execution and back' do
        service = Expeditor::Service.new(threshold: 0.2, non_break_count: 100, sleep: 0, period: 0.1)
        failure_commands = 20.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end
        end
        success_commands = 80.times.map do
          Expeditor::Command.new(service: service) do
            0
          end
        end

        failure_commands.each(&:start)
        failure_commands.each(&:wait)
        start_time = Time.now
        success_commands.each(&:start)
        success_commands.each(&:wait)
        while true do
          command = Expeditor::Command.new(service: service) do
            42
          end
          command.start
          command.wait
          sleep 0.001
          begin
            command.get
            break
          rescue
          end
        end
        expect(Time.now - start_time).to be_between(0.088, 0.102)
        service.shutdown
      end
    end

    context 'with circuit break (large case)' do
      specify 'circuit will be opened after 100 failure and it skips success_commands' do
        service = Expeditor::Service.new(
          executor: Concurrent::ThreadPoolExecutor.new(max_threads: 100),
          threshold: 0.1,
          non_break_count: 1000,
          period: 100,
          sleep: 100, # Should be larger than test case execution time.
        )

        # At first, runs failure_commands and open the circuit.
        failure_commands = 2000.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end.set_fallback { 1 }.start
        end

        # Then runs success_commands but it will be skiped and calls fallback logic.
        success_commands = 8000.times.map do
          Expeditor::Command.new(service: service) do
            raise "Won't reach here"
          end.set_fallback { 1 }.start
        end

        reason = nil
        result = Object.new
        deps = failure_commands + success_commands
        command = Expeditor::Command.new(service: service, dependencies: deps) do |_|
          raise "Won't reach here"
        end.set_fallback do |e|
          reason = e
          result
        end
        command.start

        expect(command.get).to eq(result)
        expect(reason).to be_instance_of(Expeditor::CircuitBreakError)
        service.shutdown
      end
    end

    context 'with dependency\'s error of circuit break ' do
      it 'should not fall deadlock' do
        service = Expeditor::Service.new(
          executor: Concurrent::ThreadPoolExecutor.new(max_threads: 100),
          threshold: 0.2,
          non_break_count: 10,
          period: 10,
          sleep: 0,
        )
        failure_commands = 20.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end.set_fallback do
            1
          end
        end
        success_commands = 80.times.map do
          Expeditor::Command.new(service: service) do
            1
          end
        end
        command = Expeditor::Command.new(
          service: service,
          dependencies: failure_commands + success_commands,
        ) do |*vs|
          vs.inject(:+)
        end.set_fallback do |e|
          0
        end
        command.start
        expect(command.get).to eq(0)
        service.shutdown
      end
    end
  end
end
