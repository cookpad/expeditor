require 'spec_helper'

RSpec.describe Expeditor::RingBuffer do
  def build
    Expeditor::RingBuffer.new(3) { 1 }
  end

  describe '#all' do
    it 'returns all elements' do
      expect(build.all).to eq([1, 1, 1])
    end
  end

  describe '#current' do
    it 'returns current element' do
      expect(build.current).to eq(1)
    end
  end

  describe '#move' do
    let(:size) { 3 }
    let(:dirty_ring) { Expeditor::RingBuffer.new(size) { '' } }
    before do
      dirty_ring.current << '0'
      (size - 1).times do |i|
        dirty_ring.move(1)
        dirty_ring.current << (i + 1).to_s
      end
    end

    context 'when times < size' do
      it 'moves given times with initialization' do
        expect(dirty_ring.current).to eq('2')
        expect(dirty_ring.all).to eq(%w[0 1 2])

        dirty_ring.move(1)
        expect(dirty_ring.current).to eq('')
      end
    end

    context 'when times > size' do
      it 'moves given times with initialization' do
        dirty_ring.move(size + 1)
        expect(dirty_ring.all).to eq(['', '', ''])
      end
    end

    context 'when optimized situation (time > size * 2)' do
      it 'moves given times with initialization' do
        dirty_ring.move(size * 2 + 1)
        expect(dirty_ring.all).to eq(['', '', ''])
      end
    end
  end
end
