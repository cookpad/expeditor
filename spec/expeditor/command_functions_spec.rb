require 'spec_helper'

describe Expeditor::Command do

  def simple_command(v, opts = {})
    Expeditor::Command.new(opts) do
      v
    end
  end

  def sleep_command(n, v, opts = {})
    Expeditor::Command.new(opts) do
      sleep n
      v
    end
  end

  def error_command(e, v, opts = {})
    Expeditor::Command.new(opts) do
      raise e
      v
    end
  end

  describe 'dependencies function' do
    context 'with normal and no sleep' do
      it 'should be ok' do
        command1 = simple_command('The world of truth is...: ')
        command2 = simple_command(42)
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2.to_s
        end
        command3.start
        expect(command3.get).to eq('The world of truth is...: 42')
      end
    end

    context 'with normal and sleep' do
      it 'should start dependencies concurrently' do
        start = Time.now
        command1 = sleep_command(0.1, 1)
        command2 = sleep_command(0.2, 2)
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect(command3.get).to eq(3)
        expect(Time.now - start).to be < 0.21
      end
    end

    context 'with failure' do
      it 'should throw error DependencyError' do
        command1 = simple_command(42)
        command2 = error_command(RuntimeError, 42)
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect { command3.get }.to raise_error(Expeditor::DependencyError)
      end
    end

    context 'with sleep and failure' do
      it 'should throw error immediately' do
        start = Time.now
        command1 = sleep_command(0.1, 42)
        command2 = error_command(RuntimeError, 100)
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect { command3.get }.to raise_error(Expeditor::DependencyError)
        expect(Time.now - start).to be < 0.1
      end
    end

    context 'with large number of horizontal dependencies' do
      it 'should be ok' do
        commands = 10000.times.map do
          sleep_command(0.01, 1)
        end
        command = Expeditor::Command.new(dependencies: commands) do |*vs|
          vs.inject(:+)
        end
        command.start
        expect(command.get).to eq(10000)
      end
    end

    context 'with large number of horizontal dependencies ^ 2 (long test case)' do
      it 'should be ok' do
        commands = 300.times.map do
          commands = 300.times.map do
            sleep_command(0.001, 1)
          end
          command = Expeditor::Command.new(dependencies: commands) do |*vs|
            vs.inject(:+)
          end
        end
        command = Expeditor::Command.new(dependencies: commands) do |*vs|
          vs.inject(:+)
        end
        start = Time.now
        command.start
        expect(command.get).to eq(90000)
      end
    end

    context 'with large number of vertical dependencies' do
      it 'should be ok' do
        command0 = simple_command(0)
        command = 1000.times.inject(command0) do |c|
          Expeditor::Command.new(dependencies: [c]) do |v|
            v + 1
          end
        end
        command.start
        expect(command.get).to eq(1000)
      end
    end
  end

  describe 'fallback function' do
    context 'with normal' do
      it 'should be normal value' do
        command = simple_command(42).with_fallback { 0 }
        command.start
        expect(command.get).to eq(42)
      end
    end

    context 'with failure of normal' do
      it 'should be fallback value' do
        command = error_command(RuntimeError, 42).with_fallback { 0 }
        command.start
        expect(command.get).to eq(0)
      end
    end

    context 'with fail both' do
      it 'should throw fallback error' do
        command = error_command(RuntimeError, 42).with_fallback do
          raise Exception
        end
        command.start
        expect { command.get }.to raise_error(Exception)
      end
    end

    context 'with large number of commands' do
      it 'should not throw any errors' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_threads: 10, min_threads: 10, max_queue: 100))
        commands = 1000.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end.with_fallback do |e|
            1
          end
        end
        commands.each(&:start)
        sum = commands.map(&:get).inject(:+)
        expect(sum).to eq(1000)
        service.shutdown
      end
    end
  end

  describe 'circuit break function' do
    context 'with circuit break' do
      it 'should reject execution' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_queue: 0), threshold: 0.5, non_break_count: 99, per: 0.01, size: 10)
        commands = 100.times.map do
          Expeditor::Command.new(service: service) do
            raise RuntimeError
          end.with_fallback do |e|
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
        service = Expeditor::Service.new(threshold: 0.2, non_break_count: 99, per: 0.01, size: 10)
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
        expect(Time.now - start_time).to be_between(0.09, 0.10)
        service.shutdown
      end
    end

    context 'with circuit break (large case)' do
      it 'should be ok' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_threads: 100), threshold: 0.2, non_break_count: 9999, per: 1, size: 10)
        failure_commands = 2000.times.map do
          Expeditor::Command.start(service: service) do
            raise RuntimeError
          end.with_fallback do
            sleep 0.001
            1
          end
        end
        success_commands = 8000.times.map do
          Expeditor::Command.start(service: service) do
            sleep 0.001
            1
          end
        end
        (failure_commands + success_commands).each(&:wait)
        reason = nil
        command = Expeditor::Command.start(
          service: service,
          dependencies: failure_commands + success_commands,
        ) do |*vs|
          vs.inject(:+)
        end.with_fallback do |e|
          reason = e
          0
        end
        command.wait
        expect(command.get).to eq(0)
        expect(reason).to be_instance_of(Expeditor::CircuitBreakError)
        service.shutdown
      end
    end
  end

  describe 'entire' do
    context 'with complex example' do
      it 'should be ok' do
        start = Time.now
        command1 = sleep_command(0.1, 1)
        command2 = sleep_command(1000, 'timeout!', timeout: 0.5)
        fallback_command2 = command2.with_fallback do |e|
          2
        end
        command3 = Expeditor::Command.new(dependencies: [command1, fallback_command2]) do |v1, v2|
          sleep 0.2
          v1 + v2 + 4
        end
        command4 = Expeditor::Command.new(dependencies: [command2, command3]) do |v2, v3|
          sleep 0.3
          v2 + v3 + 8
        end
        fallback_command4 = command4.with_fallback do
          8
        end

        fallback_command4.start

        expect(command1.get).to eq(1)
        expect(fallback_command4.get).to eq(8)
        expect(Time.now - start).to be < 0.52

        expect(command1.get).to eq(1)
        expect(fallback_command2.get).to eq(2)
        expect(command3.get).to eq(7)
        expect(Time.now - start).to be < 0.72
      end
    end
  end
end
