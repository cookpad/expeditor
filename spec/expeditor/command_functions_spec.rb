require 'spec_helper'

RSpec.describe Expeditor::Command do
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
      let(:event) { Concurrent::Event.new }

      it 'should start dependencies concurrently' do
        command1 = Expeditor::Command.new { event.wait(1); 1 }
        command2 = Expeditor::Command.new { event.set; 2 }
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect(command3.get).to eq(3)
      end
    end

    context 'with failure' do
      it 'should throw error DependencyError' do
        command1 = simple_command(42)
        command2 = error_command(error_in_command)
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect { command3.get }.to raise_error(Expeditor::DependencyError)
      end
    end

    context 'with sleep and failure' do
      let(:sleep_time) { 1 }

      it 'should throw error immediately' do
        command1 = sleep_command(sleep_time, 42)
        command2 = error_command(error_in_command)
        command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |v1, v2|
          v1 + v2
        end

        command3.start
        start = Time.now
        expect { command3.get }.to raise_error(Expeditor::DependencyError)
        expect(Time.now - start).to be < sleep_time
      end
    end

    context 'with large number of horizontal dependencies' do
      it 'should be ok' do
        commands = 100.times.map do
          simple_command(1)
        end
        command = Expeditor::Command.new(dependencies: commands) do |*vs|
          vs.inject(:+)
        end
        command.start
        expect(command.get).to eq(100)
      end
    end

    context 'with large number of horizontal dependencies ^ 2 (long test case)' do
      it 'should be ok' do
        commands = 20.times.map do
          dependencies = 20.times.map do
            simple_command(1)
          end
          Expeditor::Command.new(dependencies: dependencies) do |*vs|
            vs.inject(:+)
          end
        end
        command = Expeditor::Command.new(dependencies: commands) do |*vs|
          vs.inject(:+)
        end
        command.start
        expect(command.get).to eq(400)
      end
    end

    context 'with large number of vertical dependencies' do
      it 'should be ok' do
        command0 = simple_command(0)
        command = 100.times.inject(command0) do |c|
          Expeditor::Command.new(dependencies: [c]) do |v|
            v + 1
          end
        end
        command.start
        expect(command.get).to eq(100)
      end
    end
  end

  describe 'entire' do
    context 'with complex example' do
      it 'should be ok' do
        command1 = sleep_command(0.1, 1)
        command2 = sleep_command(1000, 'timeout!', timeout: 0.5)
        fallback_command2 = command2.set_fallback do |e|
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
        fallback_command4 = command4.set_fallback do
          8
        end

        start = Time.now
        fallback_command4.start

        # command is same as fallback command.
        expect(command2).to eq fallback_command2
        expect(command4).to eq fallback_command4

        expect(command1.get).to eq(1)
        expect(Time.now - start).to be < 0.12
        expect(fallback_command4.get).to eq(17)
        expect(Time.now - start).to be < 1.12

        expect(command1.get).to eq(1)
        expect(fallback_command2.get).to eq(2)
        expect(command3.get).to eq(7)
        expect(Time.now - start).to be < 1.12
      end
    end
  end
end
