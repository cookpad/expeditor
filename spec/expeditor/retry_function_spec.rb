require 'spec_helper'

describe Expeditor::Command do
  describe '#start_with_retry' do
    context 'with 3 tries' do
      it 'should be run 3 times' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command.start_with_retry(tries: 3, sleep: 0)
        expect { command.get }.to raise_error(RuntimeError)
        expect(count).to eq(3)
      end
    end

    context 'with 0 tries' do
      it 'should be run 0 time and return nil' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command.start_with_retry(tries: 0, sleep: 0)
        expect(command.get).to be_nil
        expect(count).to eq(0)
      end
    end

    context 'with retry -1 time' do
      it 'should be run 1 times' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command.start_with_retry(tries: -1, sleep: 0)
        expect { command.get }.to raise_error(RuntimeError)
        expect(count).to eq(1)
      end
    end

    context 'with passsing error' do
      it 'should not retry' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command.start_with_retry(tries: 5, sleep: 0, on: ArgumentError)
        expect { command.get }.to raise_error(RuntimeError)
        expect(count).to eq(1)
      end
    end

    context 'with retry in case of only specified errors' do
      it 'should retry' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError if count < 2
          raise ArgumentError if count < 3
          raise StandardError
        end
        command.start_with_retry(tries: 5, sleep: 0, on: [ArgumentError, RuntimeError])
        expect { command.get }.to raise_error(StandardError)
        expect(count).to eq(3)
      end
    end

    context 'with retry and timeout' do
      it 'should be timed out when over time' do
        command = Expeditor::Command.new(timeout: 0.01) do
          raise RuntimeError
        end
        command.start_with_retry(tries: 100, sleep: 0.001)
        expect { command.get }.to raise_error(Timeout::Error)
      end
    end

    context 'with retry and circuit break' do
      it 'should break when over threshold' do
        service = Expeditor::Service.new(threshold: 1, non_break_count: 100)
        command = Expeditor::Command.new(service: service) do
          raise RuntimeError
        end
        command.start_with_retry(tries: 101, sleep: 0, on: [RuntimeError])
        expect { command.get }.to raise_error(Expeditor::CircuitBreakError)
      end
    end

    context 'with retry with fallback' do
      it 'should retry if start fallback command' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end.with_fallback do
          42
        end
        command.start_with_retry(tries: 10, sleep: 0)
        expect(command.get).to eq(42)
        expect(count).to eq(10)
      end

      it 'should retry if start normal command' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command_f = command.with_fallback do
          42
        end
        command.start_with_retry(tries: 10, sleep: 0)
        expect(command_f.get).to eq(42)
        expect(count).to eq(10)
      end
    end

    context 'with (1) start and (2) start_with_retry' do
      it 'should ignore start_with_retry' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command.start
        command.start_with_retry(tries: 10, sleep: 0)
        command.wait
        expect(count).to eq(1)
      end
    end

    context 'with (1) start_with_retry and (2) start' do
      it 'should ignore start' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          raise RuntimeError
        end
        command.start_with_retry(tries: 10, sleep: 0)
        command.start
        command.wait
        expect(count).to eq(10)
      end
    end
  end
end
