require 'spec_helper'

RSpec.describe Expeditor::Command do
  let(:error_in_command) { Class.new(StandardError) }

  describe '#start' do
    context 'with normal' do
      it 'should not block' do
        command = sleep_command(1, 42)

        start = Time.now
        command.start
        expect(Time.now - start).to be < 1
      end

      it 'should return self' do
        command = simple_command(42)
        expect(command.start).to eq(command)
      end

      it 'should ignore from the second time' do
        count = Concurrent::CAtomicFixnum.new(0)
        command = Expeditor::Command.new do
          count.increment
          count
        end
        3.times { command.start }
        expect(command.get.value).to eq(1)
        expect(count.value).to eq(1)
      end
    end

    context 'with thread pool overflow' do
      it 'should throw RejectedExecutionError in #get, not #start' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_threads: 1, min_threads: 1, max_queue: 1))
        mutex = Mutex.new
        command1 = Expeditor::Command.new(service: service) do
          begin
            mutex.lock
            1
          ensure
            mutex.unlock
          end
        end
        command2 = simple_command(2, service: service)
        command3 = simple_command(3, service: service)

        mutex.lock
        command1.start
        command2.start
        command3.start
        mutex.unlock

        expect(command1.get).to eq(1)
        expect(command2.get).to eq(2)
        expect { command3.get }.to raise_error(Expeditor::RejectedExecutionError)
        service.shutdown
      end
    end

    context 'with double starting and circuit breaking' do
      let(:period) { 0.01 }
      let(:service) { Expeditor::Service.new(threshold: 0.1, non_break_count: 0, sleep: 0, period: period) }
      let(:commands) do
        1000.times.map do
          error_command(error_in_command, service: service).set_fallback { 1 }
        end
      end

      # See original test case in df2ea9a957f2eea3889f73187d1915f3eee998a9.
      it 'should not throw MultipleAssignmentError' do
        10.times { commands.each(&:start) }
        commands.each(&:wait)
        # Wait untill circuit is closed.
        sleep period * 2

        command = Expeditor::Command.start(service: service, dependencies: commands) do |*vs|
          vs.inject(:+)
        end
        expect(command.get).to eq(1000)
        service.shutdown
      end
    end
  end

  describe '#started?' do
    context 'with started' do
      it 'should be true' do
        command = simple_command(42)
        command.start
        expect(command.started?).to be true
      end
    end

    context 'with not started' do
      it 'should be falsy' do
        command = simple_command(42)
        expect(command.started?).to be_falsy
      end
    end

    context 'with fallback' do
      it 'should be true (both) if the command with no fallback is started' do
        command = simple_command(42)
        fallback_command = command.set_fallback { 0 }
        expect(command.started?).to be_falsy
        expect(fallback_command.started?).to be_falsy
        command.start
        expect(command.started?).to be true
        expect(fallback_command.started?).to be true
      end

      it 'should be true (both) if the command with fallback is started' do
        command = simple_command(42)
        fallback_command = command.set_fallback { 0 }
        expect(command.started?).to be_falsy
        expect(fallback_command.started?).to be_falsy
        fallback_command.start
        expect(command.started?).to be true
        expect(fallback_command.started?).to be true
      end
    end
  end

  describe '#get' do
    context 'with success' do
      it 'should return success value' do
        command = simple_command(42).start
        expect(command.get).to eq(42)
      end
    end

    context 'with sleep and success' do
      let(:sleep_time) { 0.001 }
      let(:command) { sleep_command(sleep_time, 42).start }

      it 'should block and return success value' do
        start = Time.new
        expect(command.get).to eq(42)
        expect(Time.now - start).to be > sleep_time
      end
    end

    context 'with failure' do
      it 'should throw exception' do
        command = error_command(error_in_command).start
        expect { command.get }.to raise_error(error_in_command)
      end

      it 'should throw exception without deadlock' do
        error = Class.new(Exception)
        command = error_command(error).start
        expect { command.get }.to raise_error(error)
      end
    end

    context 'with not started' do
      it 'should throw NotStartedError' do
        command = simple_command(42)
        expect { command.get }.to raise_error(Expeditor::NotStartedError)
      end
    end

    context 'with timeout' do
      let(:sleep_time) { 1 }
      let(:command) { sleep_command(sleep_time, 42, timeout: 0.001) }
      before { command.start }

      it 'should throw Timeout::Error' do
        start = Time.now
        expect { command.get }.to raise_error(Timeout::Error)
        expect(Time.now - start).to be < sleep_time
      end
    end
  end

  describe '#set_fallback' do
    it 'should return new command' do
      command = simple_command(42)
      fallback_command = command.set_fallback do
        0
      end
      expect(fallback_command).to eq(command)
    end

    it 'should not block' do
      command = error_command(error_in_command)
      start_time = Time.now
      fallback_command = command.set_fallback do
        sleep 1
        0
      end
      expect(Time.now - start_time).to be < 1
    end

    context 'with normal success' do
      it 'should return normal result' do
        command = simple_command(42).set_fallback { 0 }.start
        expect(command.get).to eq(42)
      end
    end

    context 'after #start called' do
      it 'should throw AlreadyStartedError' do
        command = simple_command(42)
        command.start
        expect { command.set_fallback{} }.to raise_error(Expeditor::AlreadyStartedError)
      end
    end
  end

  describe '#wait' do
    let(:sleep_time) { 0.001 }

    context 'without fallback' do
      it 'should wait execution' do
        command = sleep_command(sleep_time, nil)
        command.start

        start_time = Time.now
        command.wait
        expect(Time.now - start_time).to be > sleep_time
      end
    end

    context 'with fallback' do
      it 'should wait execution' do
        command = Expeditor::Command.new {
          sleep sleep_time
          raise error_in_command
        }.set_fallback {
          sleep sleep_time
          nil
        }

        start_time = Time.now
        command.start.wait
        expect(Time.now - start_time).to be > (sleep_time * 2)
      end
    end

    context 'with fallback but normal success' do
      it 'should not wait fallback execution' do
        command = simple_command(42).set_fallback do
          sleep sleep_time
          0
        end

        start_time = Time.now
        command.start.wait
        expect(Time.now - start_time).to be < sleep_time
        expect(command.get).to eq(42)
      end
    end

    context 'with fail both' do
      let(:error_in_fallback) { Class.new(Exception) }

      it 'should throw fallback error' do
        command = error_command(error_in_command).set_fallback do
          raise error_in_fallback
        end
        command.start
        expect { command.get }.to raise_error(error_in_fallback)
      end
    end

    context 'with large number of commands' do
      it 'should not throw any errors' do
        service = Expeditor::Service.new(executor: Concurrent::ThreadPoolExecutor.new(max_threads: 10, min_threads: 10, max_queue: 100))
        commands = 100.times.map do
          Expeditor::Command.new(service: service) do
            raise error_in_command
          end.set_fallback do |e|
            1
          end
        end
        commands.each(&:start)
        sum = commands.map(&:get).inject(:+)
        expect(sum).to eq(100)
        service.shutdown
      end
    end

    context 'with not started' do
      it 'should throw NotStartedError without waiting' do
        command = sleep_command(sleep_time, 42)
        start = Time.now
        expect { command.wait }.to raise_error(Expeditor::NotStartedError)
        expect(Time.now - start).to be < sleep_time
      end
    end
  end

  describe '#on_complete' do
    context 'with normal success and without fallback' do
      it 'should run callback with success' do
        command = simple_command(42)
        success, value, reason = nil, nil, nil
        command.on_complete do |s, v, r|
          success, value, reason = s, v, r
        end
        command.start.wait
        expect(success).to be true
        expect(value).to eq(42)
        expect(reason).to be_nil
      end
    end

    context 'with normal success and with fallback' do
      it 'should run callback with success' do
        command = simple_command(42).set_fallback { 0 }
        success, value, reason = nil, nil, nil
        command.on_complete do |s, v, r|
          success, value, reason = s, v, r
        end
        command.start.wait
        expect(success).to be true
        expect(value).to eq(42)
        expect(reason).to be_nil
      end
    end

    context 'with normal failure and without fallback' do
      it 'should run callback with failure' do
        command = error_command(error_in_command)
        success, value, reason = nil, nil, nil
        command.on_complete do |s, v, r|
          success, value, reason = s, v, r
        end
        command.start.wait
        expect(success).to be false
        expect(value).to be_nil
        expect(reason).to be_instance_of(error_in_command)
      end
    end

    context 'with normal failure and with fallback success' do
      it 'should run callback with success' do
        command = error_command(error_in_command).set_fallback { 0 }
        success, value, reason = nil, nil, nil
        command.on_complete do |s, v, r|
          success, value, reason = s, v, r
        end
        command.start.wait
        expect(success).to be true
        expect(value).to eq(0)
        expect(reason).to be_nil
      end
    end

    context 'with normal failure and with fallback failure' do
      it 'should run callback with failure' do
        command = error_command(error_in_command).set_fallback do |e|
          raise e
        end
        success, value, reason = nil, nil, nil
        command.on_complete do |s, v, r|
          success, value, reason = s, v, r
        end
        command.start.wait
        expect(success).to be false
        expect(value).to be_nil
        expect(reason).to be_instance_of(error_in_command)
      end
    end
  end

  describe '#on_success' do
    context 'with normal success and without fallback' do
      it 'should run callback' do
        command = simple_command(42)
        res = nil
        command.on_success do |v|
          res = v
        end
        command.start.wait
        expect(res).to eq(42)
      end
    end

    context 'with normal success and with fallback' do
      it 'should run callback' do
        command = simple_command(42).set_fallback { 0 }
        res = nil
        command.on_success do |v|
          res = v
        end
        command.start.wait
        expect(res).to eq(42)
      end
    end

    context 'with normal failure and without fallback' do
      it 'should not run callback' do
        command = error_command(error_in_command)
        res = nil
        command.on_success do |v|
          res = v
        end
        command.start.wait
        expect(res).to be_nil
      end
    end

    context 'with normal failure and with fallback success' do
      it 'should run callback' do
        command = error_command(error_in_command).set_fallback do
          0
        end
        res = nil
        command.on_success do |v|
          res = v
        end
        command.start.wait
        expect(res).to eq(0)
      end
    end

    context 'with normal failure and with fallback failure' do
      it 'should not run callback' do
        command = error_command(error_in_command).set_fallback do |e|
          raise e
        end
        res = nil
        command.on_success do |v|
          res = v
        end
        command.start.wait
        expect(res).to be_nil
      end
    end
  end

  describe '#on_failure' do
    context 'with normal success and without fallback' do
      it 'should not run callback' do
        command = simple_command(42)
        flag = false
        command.on_failure do |e|
          flag = true
        end
        command.start.wait
        expect(flag).to be false
      end
    end

    context 'with normal failure and without fallback' do
      it 'should run callback' do
        command = error_command(error_in_command)
        flag = false
        command.on_failure do |e|
          flag = true
        end
        command.start.wait
        expect(flag).to be true
      end
    end

    context 'with normal success and with fallback' do
      it 'should not run callback' do
        command = simple_command(42).set_fallback do
          0
        end
        flag = false
        command.on_failure do |e|
          flag = true
        end
        command.start.wait
        expect(flag).to be false
      end
    end

    context 'with normal failure and with fallback success' do
      it 'should not run callback' do
        command = error_command(error_in_command).set_fallback do
          0
        end
        flag = false
        command.on_failure do |e|
          flag = true
        end
        command.start.wait
        expect(flag).to be false
      end
    end

    context 'with normal failure and with fallback failure' do
      it 'should run callback' do
        command = error_command(error_in_command).set_fallback do |e|
          raise e
        end
        flag = false
        command.on_failure do |e|
          flag = true
        end
        command.start.wait
        expect(flag).to be true
      end
    end
  end

  describe '#chain' do
    context 'with normal' do
      it 'should chain command' do
        command_double = simple_command(42).chain do |n|
          n * 2
        end
        command_double.start
        expect(command_double.get).to eq(84)
      end
    end

    context 'with options' do
      it 'should recognize options' do
        command_sleep = simple_command(42).chain(timeout: 0.001) do
          sleep 0.1
          nil
        end.start
        expect { command_sleep.get }.to raise_error(Timeout::Error)
      end
    end
  end

  describe '.const' do
    it 'should be ok' do
      command = Expeditor::Command.const(42)
      expect(command.started?).to be true
      expect(command.start).to eq(command)
      expect(command.get).to eq(42)
    end
  end

  describe '.start' do
    it 'should be already started' do
      command = Expeditor::Command.start do
        42
      end
      expect(command.started?).to be true
      expect(command.get).to be 42
    end
  end
end
