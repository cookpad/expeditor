require 'spec_helper'

describe Rystrix::RichFuture do
  describe '#get' do
    context 'with success' do
      it 'should return normal value' do
        future = Rystrix::RichFuture.new do
          42
        end
        future.execute
        expect(future.get).to eq(42)
      end
    end

    context 'with failure' do
      it 'should raise exception' do
        future = Rystrix::RichFuture.new do
          raise RuntimeError
        end
        future.execute
        expect { future.get }.to raise_error(RuntimeError)
      end
    end
  end
end
