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

  let(:error_in_command) { Class.new(StandardError) }

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
        command2 = error_command(error_in_command, 42)
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
        command2 = error_command(error_in_command, 100)
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
        commands = 100.times.map do
          dependencies = 100.times.map do
            simple_command(1)
          end
          Expeditor::Command.new(dependencies: dependencies) do |*vs|
            vs.inject(:+)
          end
        end
        command = Expeditor::Command.new(dependencies: commands) do |*vs|
          vs.inject(:+)
        end
        start = Time.now
        command.start
        expect(command.get).to eq(10000)
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
        command = error_command(error_in_command, 42).with_fallback { 0 }
        command.start
        expect(command.get).to eq(0)
      end
    end

    context 'with fail both' do
      let(:error_in_fallback) { Class.new(Exception) }

      it 'should throw fallback error' do
        command = error_command(error_in_command, 42).with_fallback do
          raise error_in_fallback
        end
        command.start
        expect { command.get }.to raise_error(error_in_fallback)
      end
    end

    context 'with large number of commands' do
      it 'should not throw any errors' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_threads: 10, min_threads: 10, max_queue: 100))
        commands = 1000.times.map do
          Expeditor::Command.new(service: service) do
            raise error_in_command
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
