require 'spec_helper'

describe Rystrix::Service do
  describe '#open?' do
    context 'with no count' do
      it 'should be false' do
        options = {
          threshold: 0,
          non_break_count: 0,
        }
        service = Rystrix::Service.new(options)
        expect(service.open?).to be false
      end
    end

    context 'within non_break_count' do
      it 'should be false' do
        options = {
          threshold: 0.0,
          non_break_count: 100,
        }
        service = Rystrix::Service.new(options)
        100.times do
          service.failure
        end
        expect(service.open?).to be false
      end
    end

    context 'with non_break_count exceeded but not exceeded threshold' do
      it 'should be false' do
        options = {
          threshold: 0.2,
          non_break_count: 99,
        }
        service = Rystrix::Service.new(options)
        81.times do
          service.success
        end
        19.times do
          service.failure
        end
        expect(service.open?).to be false
      end
    end

    context 'with non_break_count and threshold exceeded' do
      it 'should be true' do
        options = {
          threshold: 0.2,
          non_break_count: 99,
        }
        service = Rystrix::Service.new(options)
        80.times do
          service.success
        end
        20.times do
          service.failure
        end
        expect(service.open?).to be true
      end
    end
  end
end
