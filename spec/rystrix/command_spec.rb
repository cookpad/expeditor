require 'spec_helper'

describe Rystrix::Command do

  def simple_command(v, opts = {})
    Rystrix::Command.new(opts) do
      v
    end
  end

  def sleep_command(n, v, opts = {})
    Rystrix::Command.new(opts) do
      sleep n
      v
    end
  end

  def error_command(e, v, opts = {})
    Rystrix::Command.new(opts) do
      raise e
      v
    end
  end

  describe '#execute' do
    it 'should not block' do
      start = Time.now
      command = sleep_command(1, 42)
      command.execute
      expect(Time.now - start).to be < 1
    end

    it 'should return self' do
      command = simple_command(42)
      expect(command.execute).to eq(command)
    end
  end

  describe '#executed?' do
    context 'with executed' do
      it 'should be true' do
        command = simple_command(42)
        command.execute
        expect(command.executed?).to be true
      end
    end

    context 'with not executed' do
      it 'should be false' do
        command = simple_command(42)
        expect(command.executed?).to be false
      end
    end

    context 'with fallback' do
      it 'should be true (only no fallback) if the command with no fallback is executed' do
        command = simple_command(42)
        fallback_command = command.with_fallback { 0 }
        expect(command.executed?).to be false
        expect(fallback_command.executed?).to be false
        command.execute
        expect(command.executed?).to be true
        expect(fallback_command.executed?).to be false
        fallback_command.execute
        expect(command.executed?).to be true
        expect(fallback_command.executed?).to be true
      end

      it 'should be true (both) if the command with fallback is executed' do
        command = simple_command(42)
        fallback_command = command.with_fallback { 0 }
        expect(command.executed?).to be false
        expect(fallback_command.executed?).to be false
        fallback_command.execute
        expect(command.executed?).to be true
        expect(fallback_command.executed?).to be true
      end
    end
  end

  describe '#get' do
    context 'with success' do
      it 'should return success value' do
        command = simple_command(42)
        command.execute
        expect(command.get).to eq(42)
      end
    end

    context 'with sleep and success' do
      it 'should block and return success value' do
        start = Time.new
        command = sleep_command(0.1, 42)
        command.execute
        expect(command.get).to eq(42)
        expect(Time.now - start).to be > 0.1
      end
    end

    context 'with failure' do
      it 'should throw exception' do
        command = error_command(RuntimeError, nil)
        command.execute
        expect { command.get }.to raise_error(RuntimeError)
      end
    end

    context 'with not executed' do
      it 'should throw NotExecutedYetError' do
        command = simple_command(42)
        expect { command.get }.to raise_error(Rystrix::NotExecutedYetError)
      end
    end

    context 'with timeout' do
      it 'should throw TimeoutError' do
        start = Time.now
        command = sleep_command(1, 42, timeout: 0.1)
        command.execute
        expect { command.get }.to raise_error(Rystrix::TimeoutError)
        expect(Time.now - start).to be < 0.11
      end
    end
  end

  describe '#with_fallback' do
    it 'should return new command and same normal_future' do
      command = simple_command(42)
      fallback_command = command.with_fallback do
        0
      end
      expect(fallback_command).not_to eq(command)
      # expect(fallback_command.normal_future).to eq(command.normal_future)
    end
  end

  describe 'args function' do
    context 'with normal and no sleep' do
      it 'should be ok' do
        command1 = simple_command('The world of truth is...: ')
        command2 = simple_command(42)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2.to_s
        end
        command3.execute
        expect(command3.get).to eq('The world of truth is...: 42')
      end
    end

    context 'with normal and sleep' do
      it 'should execute args concurrently' do
        start = Time.now
        command1 = sleep_command(0.1, 1)
        command2 = sleep_command(0.2, 2)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.execute
        expect(command3.get).to eq(3)
        expect(Time.now - start).to be < 0.21
      end
    end

    context 'with failure' do
      it 'should throw error of args' do
        command1 = simple_command(42)
        command2 = error_command(RuntimeError, 42)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.execute
        expect { command3.get }.to raise_error(RuntimeError)
      end
    end

    context 'with sleep and failure' do
      it 'should throw error immediately' do
        start = Time.now
        command1 = sleep_command(0.1, 42)
        command2 = error_command(RuntimeError, 100)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.execute
        expect { command3.get }.to raise_error(RuntimeError)
        expect(Time.now - start).to be < 0.1
      end
    end
  end

  describe 'fallback function' do
    context 'with normal' do
      it 'should be normal value' do
        command = simple_command(42).with_fallback { 0 }
        command.execute
        expect(command.get).to eq(42)
      end
    end

    context 'with failure of normal' do
      it 'should be fallback value' do
        command = error_command(RuntimeError, 42).with_fallback { 0 }
        command.execute
        expect(command.get).to eq(0)
      end
    end

    context 'with fail both' do
      it 'should throw fallback error' do
        command = error_command(RuntimeError, 42).with_fallback do
          raise Exception
        end
        command.execute
        expect { command.get }.to raise_error(Exception)
      end
    end
  end
end
