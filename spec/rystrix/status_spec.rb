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
    end
  end
end
