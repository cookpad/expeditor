require 'spec_helper'

RSpec.describe Expeditor::Bucket do
  describe '#increment' do
    context 'with same status' do
      it 'should be increased' do
        bucket = Expeditor::Bucket.new(size: 10, per: 1)
        bucket.increment :success
        bucket.increment :success
        bucket.increment :success
        expect(bucket.current.success).to eq(3)
      end
    end

    context 'across statuses' do
      it 'should be ok' do
        bucket = Expeditor::Bucket.new(size: 10, per: 0.01)
        bucket.increment :success
        sleep 0.01
        bucket.increment :success
        expect(bucket.current.success).to eq(1)
      end
    end
  end

  describe '#total' do
    context 'with no limit exceeded' do
      it 'should be ok' do
        size = 1000
        per = 0.001
        bucket = Expeditor::Bucket.new(size: size, per: per)
        20.times do |n|
          bucket.increment :success
          sleep 0.002
        end
        expect(bucket.current.success).not_to eq(20)
        expect(bucket.total.success).to eq(20)
      end
    end

    context 'with limit exceeded' do
      it 'should be ok' do
        size = 5
        per = 0.001
        bucket = Expeditor::Bucket.new(size: size, per: per)
        10.times do
          bucket.increment :success
        end
        sleep 0.008
        expect(bucket.total.success).to eq(0)
      end
    end
  end
end
