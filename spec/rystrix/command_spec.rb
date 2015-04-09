require 'spec_helper'

describe Rystrix::Command do
  describe '#execute' do
    it 'should not block' do
      start = Time.now
      command = Rystrix::Command.new do
        sleep 1
        42
      end
      command.execute
      expect(Time.now - start).to be < 1
    end
  end

  describe '#get' do
    context 'with success' do
      it 'should return success value' do
        command = Rystrix::Command.new do
          42
        end
        command.execute
        expect(command.get).to eq(42)
      end
    end

    context 'with sleep and success' do
      it 'should block and return success value' do
        start = Time.new
        command = Rystrix::Command.new do
          sleep 0.1
          42
        end
        command.execute
        expect(command.get).to eq(42)
        expect(Time.now - start).to be > 0.1
      end
    end

    context 'with failure' do
      it 'should throw exception' do
        command = Rystrix::Command.new do
          raise RuntimeError
        end
        command.execute
        expect { command.get }.to raise_error(RuntimeError)
      end
    end
  end
end
