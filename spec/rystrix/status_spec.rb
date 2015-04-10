require 'spec_helper'

describe Rystrix::Status do
  describe '#initialize' do
    it 'should be zero all' do
      status = Rystrix::Status.new
      expect(status.success).to eq(0)
      expect(status.failure).to eq(0)
      expect(status.rejection).to eq(0)
      expect(status.timeout).to eq(0)
    end
  end

  describe '#increment' do
    context 'with success increment' do
      it 'should be increased only success' do
        status = Rystrix::Status.new
        status.increment :success
        expect(status.success).to eq(1)
        expect(status.failure).to eq(0)
        expect(status.rejection).to eq(0)
        expect(status.timeout).to eq(0)
      end

      it 'should be increased normally if #increment is called in parallel' do
        status = Rystrix::Status.new
        threads = 1000.times.map do
          Thread.start do
            status.increment :success
          end
        end
        threads.each(&:join)
        expect(status.success).to eq(1000)
      end
    end

    context 'with all increment' do
      it 'should be increased all' do
        status = Rystrix::Status.new
        status.increment :success
        status.increment :failure
        status.increment :rejection
        status.increment :timeout
        expect(status.success).to eq(1)
        expect(status.failure).to eq(1)
        expect(status.rejection).to eq(1)
        expect(status.timeout).to eq(1)
      end
    end
  end
end
