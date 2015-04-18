require 'spec_helper'

describe Expeditor::RichFuture do
  describe '#get' do
    context 'with success' do
      it 'should return normal value' do
        future = Expeditor::RichFuture.new do
          42
        end
        future.execute
        expect(future.get).to eq(42)
      end
    end

    context 'with failure' do
      it 'should raise exception' do
        future = Expeditor::RichFuture.new do
          raise RuntimeError
        end
        future.execute
        expect { future.get }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#get_or_else' do
    context 'with success' do
      it 'should return normal value' do
        future = Expeditor::RichFuture.new do
          42
        end
        future.execute
        expect(future.get_or_else { 0 }).to eq(42)
      end
    end

    context 'with recover' do
      it 'should raise exception' do
        future = Expeditor::RichFuture.new do
          raise RuntimeError
        end
        future.execute
        expect(future.get_or_else { 0 }).to eq(0)
      end
    end

    context 'with also failure' do
      it 'should raise exception' do
        future = Expeditor::RichFuture.new do
          raise RuntimeError
        end
        future.execute
        expect { future.get_or_else { raise Exception } }.to raise_error(Exception)
      end
    end
  end

  describe '#set' do
    it 'should success immediately' do
      future = Expeditor::RichFuture.new do
        sleep 1000
        raise RuntimeError
      end
      future.execute
      future.set(42)
      expect(future.completed?).to be true
      expect(future.fulfilled?).to be true
      expect(future.get).to eq(42)
    end

    it 'should notify to observer' do
      future = Expeditor::RichFuture.new do
        sleep 1000
        raise RuntimeError
      end
      value = nil
      future.add_observer do |_, v, _|
        value = v
      end
      future.set(42)
      expect(value).to eq(42)
    end

    it 'should throw error if it is already completed' do
      future = Expeditor::RichFuture.new do
        42
      end
      future.execute
      future.wait
      expect { future.set(0) }.to raise_error(Concurrent::MultipleAssignmentError)
    end
  end

  describe '#safe_set' do
    it 'should set immediately' do
      future = Expeditor::RichFuture.new do
        sleep 1000
        raise RuntimeError
      end
      future.execute
      future.safe_set(42)
      expect(future.completed?).to be true
      expect(future.fulfilled?).to be true
      expect(future.get).to eq(42)
    end

    it 'should not throw error although it is already completed' do
      future = Expeditor::RichFuture.new do
        42
      end
      future.execute
      future.wait
      future.safe_set(0)
    end

    it 'should ignore if it is already completed' do
      future = Expeditor::RichFuture.new do
        42
      end
      future.execute
      future.wait
      future.safe_set(0)
      expect(future.value).to eq(42)
    end
  end

  describe '#fail' do
    it 'should fail immediately' do
      future = Expeditor::RichFuture.new do
        sleep 1000
        42
      end
      future.execute
      future.fail(Exception.new)
      expect(future.completed?).to be true
      expect(future.rejected?).to be true
      expect(future.reason).to be_instance_of(Exception)
    end

    it 'should notify to observer' do
      future = Expeditor::RichFuture.new do
        sleep 1000
        42
      end
      reason = nil
      future.add_observer do |_, _, r|
        reason = r
      end
      future.fail(RuntimeError.new)
      expect(reason).to be_instance_of(RuntimeError)
    end

    it 'should throw error if it is already completed' do
      future = Expeditor::RichFuture.new do
        42
      end
      future.execute
      future.wait
      expect { future.fail(RuntimeError.new) }.to raise_error(Concurrent::MultipleAssignmentError)
    end
  end

  describe '#safe_fail' do
    it 'should fail immediately' do
      future = Expeditor::RichFuture.new do
        sleep 1000
        42
      end
      future.execute
      future.safe_fail(Exception.new)
      expect(future.completed?).to be true
      expect(future.rejected?).to be true
      expect(future.reason).to be_instance_of(Exception)
    end

    it 'should not throw error although it is already completed' do
      future = Expeditor::RichFuture.new do
        42
      end
      future.execute
      future.wait
      future.safe_fail(RuntimeError.new)
    end

    it 'should ignore if it is already completed' do
      future = Expeditor::RichFuture.new do
        42
      end
      future.execute
      future.wait
      future.safe_fail(RuntimeError.new)
      expect(future.value).to eq(42)
    end
  end

  describe '#executed?' do
    context 'with executed' do
      it 'should be true' do
        future = Expeditor::RichFuture.new do
          42
        end
        future.execute
        expect(future.executed?).to be true
      end
    end

    context 'with not executed' do
      it 'should be false' do
        future = Expeditor::RichFuture.new do
          42
        end
        expect(future.executed?).to be false
      end
    end
  end

  describe '#execute' do
    context 'with thread pool overflow' do
      it 'should throw RejectedExecutionError' do
        executor = Concurrent::ThreadPoolExecutor.new(
          min_threads: 1,
          max_threads: 1,
          max_queue: 1,
        )
        future1 = Expeditor::RichFuture.new(executor: executor) do
          42
        end
        future2 = Expeditor::RichFuture.new(executor: executor) do
          42
        end
        future1.execute
        expect { future2.execute }.to raise_error(Expeditor::RejectedExecutionError)
      end
    end
  end

  describe '#safe_execute' do
    context 'with thread pool overflow' do
      it 'should not throw RejectedExecutionError' do
        executor = Concurrent::ThreadPoolExecutor.new(
          min_threads: 1,
          max_threads: 1,
          max_queue: 1,
        )
        futures = 10.times.map do
          Expeditor::RichFuture.new(executor: executor) do
            sleep 1
            42
          end
        end
        expect { futures.each(&:safe_execute) }.to_not raise_error
        futures.each(&:wait)
        expect(futures.first.get).to eq(42)
        expect { futures.last.get }.to raise_error(Expeditor::RejectedExecutionError)
      end
    end
  end
end
