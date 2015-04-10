require 'spec_helper'

describe Rystrix::Bucket do
  describe '#increment' do
    context 'with same status' do
      it 'should be increased' do
        bucket = Rystrix::Bucket.new(size: 10, par: 1)
        bucket.increment :success
        bucket.increment :success
        bucket.increment :success
        expect(bucket.current.success).to eq(3)
      end
    end

    context 'across statuses' do
      it 'should be ok' do
        bucket = Rystrix::Bucket.new(size: 10, par: 0.01)
        bucket.increment :success
        sleep 0.01
        bucket.increment :success
        expect(bucket.current.success).to eq(1)
      end
    end
  end
end
