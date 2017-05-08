require 'spec_helper'

RSpec.describe Expeditor::RollingNumber do
  describe '#increment' do
    context 'with same status' do
      it 'should be increased' do
        rolling_number = Expeditor::RollingNumber.new(size: 10, per: 1)
        rolling_number.increment :success
        rolling_number.increment :success
        rolling_number.increment :success
        expect(rolling_number.current.success).to eq(3)
      end
    end

    context 'across statuses' do
      it 'should be ok' do
        rolling_number = Expeditor::RollingNumber.new(size: 10, per: 0.01)
        rolling_number.increment :success
        sleep 0.01
        rolling_number.increment :success
        expect(rolling_number.current.success).to eq(1)
      end
    end
  end

  describe '#total' do
    context 'with no limit exceeded' do
      it 'should be ok' do
        size = 1000
        per = 0.001
        rolling_number = Expeditor::RollingNumber.new(size: size, per: per)
        20.times do |n|
          rolling_number.increment :success
          sleep 0.002
        end
        expect(rolling_number.current.success).not_to eq(20)
        expect(rolling_number.total.success).to eq(20)
      end
    end

    context 'with limit exceeded' do
      it 'should be ok' do
        size = 5
        per = 0.001
        rolling_number = Expeditor::RollingNumber.new(size: size, per: per)
        10.times do
          rolling_number.increment :success
        end
        sleep 0.008
        expect(rolling_number.total.success).to eq(0)
      end
    end
  end

  context 'passing many (> size) sliced time' do
    let(:size) { 3 }
    let(:per) { 0.01 }

    it 'resets all statuses' do
      rolling_number = Expeditor::RollingNumber.new(size: size, per: per)
      # Make all statuses dirty.
      3.times do
        3.times { rolling_number.increment(:success) }
        sleep per
      end
      # Move to next rolling_number.
      sleep per
      # Pass size + 1 rolling_numbers.
      sleep per * size
      expect(rolling_number.total.success).to eq(0)
    end
  end
end
