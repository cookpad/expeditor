require 'spec_helper'

RSpec.describe Expeditor::Command do
  describe 'circuit break function' do
    context 'with circuit break' do
      it 'should reject execution' do
        executor = Concurrent::ThreadPoolExecutor.new(max_queue: 0)
        service = Expeditor::Service.new(executor: executor, threshold: 0.1, non_break_count: 2, sleep: 1, period: 10)

        3.times do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end.start.wait
        end
        expect(service.breaking?).to eq(true)

        command = Expeditor::Command.new(service: service) { 42 }.start
        expect { command.get }.to raise_error(Expeditor::CircuitBreakError)

        service.shutdown
      end

      it 'should not count circuit break' do
        service = Expeditor::Service.new(threshold: 0, non_break_count: 0)
        5.times do
          Expeditor::Command.new(service: service) do
            raise Expeditor::CircuitBreakError
          end.start.wait
        end

        command = Expeditor::Command.new(service: service) { 42 }.start
        expect(command.get).to eq(42)

        service.shutdown
      end
    end

    context 'with circuit break and wait' do
      it 'should reject execution and back' do
        sleep_value = 0.03
        config = { threshold: 0.1, non_break_count: 5, sleep: sleep_value, period: 0.1 }
        service = Expeditor::Service.new(config)
        failure_commands = 10.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end
        end
        failure_commands.each(&:start)
        failure_commands.each(&:wait)
        expect(service.breaking?).to eq(true)

        # Store break count to compare later.
        last_breaked_count = service.status.break

        success_commands = 5.times.map do
          Expeditor::Command.new(service: service) { 0 }
        end
        success_commands.each(&:start)
        success_commands.each(&:wait)
        # The executions were short circuited.
        expect(service.breaking?).to eq(true)
        expect(service.status.break).to be > last_breaked_count

        # Wait sleep time then circuit bacomes half-open.
        sleep sleep_value + 0.01

        # The circuit is half-open now so the circuit breaker allow single
        # request to check the dependent service is healthy or not. The circuit
        # breaker will only allow single request, so subsequent requests will
        # trip the circuit. When the test request succeeds, the circuit breaker
        # will reset the status.
        command = Expeditor::Command.new(service: service) { sleep 0.01; 1 }.start
        command2 = Expeditor::Command.new(service: service) { 1 }.start
        expect { command2.get }.to raise_error(Expeditor::CircuitBreakError)
        expect(command.get).to eq(1)
        expect(service.status.success).to eq(1)
        expect(service.status.failure).to eq(0)

        # Since the last execution was succeed, the circuit becames closed.
        expect(service.breaking?).to eq(false)
        command = Expeditor::Command.new(service: service) { 1 }.start
        expect(command.get).to eq(1)

        service.shutdown
      end
    end

    context 'with circuit break (large case)' do
      specify 'circuit will be opened after 100 failure and skip success_commands' do
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

        expect(command.get).to equal(result)
        expect(reason).to be_instance_of(Expeditor::CircuitBreakError)
        service.shutdown
      end
    end

    context "with dependency's error of circuit break" do
      let(:executor) { Concurrent::ThreadPoolExecutor.new(max_threads: 100) }
      let(:service) { Expeditor::Service.new(executor: executor, threshold: 0.2, non_break_count: 10, period: 10, sleep: 5) }

      it 'should not fall deadlock' do
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
