require 'spec_helper'

describe Rystrix::Command do

  def simple_command(v)
    Rystrix::Command.new do
      v
    end
  end

  def sleep_command(n, v)
    Rystrix::Command.new do
      sleep n
      v
    end
  end

  def error_command(e, v)
    Rystrix::Command.new do
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
  end
  end
end
