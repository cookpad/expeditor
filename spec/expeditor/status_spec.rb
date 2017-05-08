require 'spec_helper'

RSpec.describe Expeditor::Status do
  describe '#initialize' do
    it 'should be zero all' do
      status = Expeditor::Status.new
      expect(status.success).to eq(0)
      expect(status.failure).to eq(0)
      expect(status.rejection).to eq(0)
      expect(status.timeout).to eq(0)
    end
  end

  describe '#increment' do
    context 'with success increment' do
      it 'should be increased only success' do
        status = Expeditor::Status.new
        status.increment :success
        expect(status.success).to eq(1)
        expect(status.failure).to eq(0)
        expect(status.rejection).to eq(0)
        expect(status.timeout).to eq(0)
      end

      it 'should be increased normally if #increment is called in parallel' do
        status = Expeditor::Status.new
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
        status = Expeditor::Status.new
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

  describe '#merge!' do
    let(:original) { Expeditor::Status.new }
    let(:other) { Expeditor::Status.new }
    before do
      i = 1
      [original, other].each do |s|
        %i[success failure rejection timeout].each do |type|
          s.increment(type, i)
          i += 1
        end
      end
    end

    it 'merges destructively and returns self' do
      back = original.success
      result = original.merge!(other)

      expect(result.success).not_to eq(back)
      expect(result.success).to eq(original.success)
      expect(result.success).not_to eq(other.success)
      expect(result).to equal(original)
    end
  end
end
