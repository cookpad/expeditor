require 'spec_helper'

RSpec.describe Expeditor::Service do
  describe '#open?' do
    context 'with no count' do
      it 'should be false' do
        options = {
          threshold: 0,
          non_break_count: 0,
        }
        service = Expeditor::Service.new(options)
        expect(service.open?).to be false
      end
    end

    context 'within non_break_count' do
      it 'should be false' do
        options = {
          threshold: 0.0,
          non_break_count: 100,
        }
        service = Expeditor::Service.new(options)
        99.times do
          service.failure
        end
        expect(service.open?).to be false
      end
    end

    context 'with non_break_count exceeded but not exceeded threshold' do
      it 'should be false' do
        options = {
          threshold: 0.2,
          non_break_count: 100,
        }
        service = Expeditor::Service.new(options)
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
          non_break_count: 100,
        }
        service = Expeditor::Service.new(options)
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

  describe '#shutdown' do
    it 'should reject execution' do
      service = Expeditor::Service.new
      service.shutdown
      command = Expeditor::Command.start(service: service) do
        42
      end
      expect { command.get }.to raise_error(Expeditor::RejectedExecutionError)
    end

    it 'should not kill queued tasks' do
      service = Expeditor::Service.new
      commands = (0..2).map do |i|
        Expeditor::Command.new(service: service) do
          # Trigger service.shutdown while processing commands
          service.shutdown if i == 1
          1
        end
      end
      command = Expeditor::Command.start(service: service, dependencies: commands) do |*vs|
        vs.inject(:+)
      end
      expect(command.get).to eq(3)
    end
  end

  describe '#status' do
    it 'returns current status' do
      # Set large value of period in case test takes long time.
      service = Expeditor::Service.new(period: 100)

      3.times do
        Expeditor::Command.new(service: service) {
          raise
        }.set_fallback { nil }.start.get
      end

      expect(service.status.success).to eq(0)
      expect(service.status.failure).to eq(3)
    end
  end

  describe '#current_status' do
    it 'warns deprecation' do
      service = Expeditor::Service.new
      expect {
        service.current_status
      }.to output(/current_status is deprecated/).to_stderr
    end
  end

  describe '#reset_status!' do
    let(:service) { Expeditor::Service.new(non_break_count: 1) }

    it "resets the service's status" do
      2.times do
        service.failure
      end
      expect(service.open?).to be(true)
      service.reset_status!
      expect(service.open?).to be(false)
    end
  end

  describe '#fallback_enabled' do
    let(:service) { Expeditor::Service.new(period: 10) }

    context 'fallback_enabled is true' do
      before do
        service.fallback_enabled = true
      end

      it 'returns fallback value' do
        result = Expeditor::Command.new(service: service) {
          raise 'error!'
        }.set_fallback {
          0
        }.start.get
        expect(result).to eq(0)
      end
    end

    context 'fallback_enabled is false' do
      before do
        service.fallback_enabled = false
      end

      it 'does not call fallback and raises error' do
        expect {
          Expeditor::Command.new(service: service) {
            raise 'error!'
          }.set_fallback {
            0
          }.start.get
        }.to raise_error(RuntimeError, 'error!')
      end
    end
  end
end
