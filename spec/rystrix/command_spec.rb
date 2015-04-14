require 'spec_helper'

describe Rystrix::Command do

  def simple_command(v, opts = {})
    Rystrix::Command.new(opts) do
      v
    end
  end

  def sleep_command(n, v, opts = {})
    Rystrix::Command.new(opts) do
      sleep n
      v
    end
  end

  def error_command(e, v, opts = {})
    Rystrix::Command.new(opts) do
      raise e
      v
    end
  end

  describe '#start' do
    context 'with normal' do
      it 'should not block' do
        start = Time.now
        command = sleep_command(1, 42)
        command.start
        expect(Time.now - start).to be < 1
      end

      it 'should return self' do
        command = simple_command(42)
        expect(command.start).to eq(command)
      end

      it 'should ignore from the second time' do
        count = 0
        command = Rystrix::Command.new do
          count += 1
          count
        end
        command.start
        command.start
        command.start
        expect(command.get).to eq(1)
        expect(count).to eq(1)
      end
    end

    context 'with thread pool overflow' do
      it 'should throw RejectedExecutionError in #get, not #start' do
        service = Rystrix::Service.new(max_threads: 1, min_threads: 1, max_queue: 1)
        command1 = simple_command(1, service: service)
        command2 = simple_command(2, service: service)
        command1.start
        command2.start
        expect(command1.get).to eq(1)
        expect { command2.get }.to raise_error(Rystrix::RejectedExecutionError)
        service.shutdown
      end
    end

    context 'with double starting' do
      it 'should not throw MultipleAssignmentError' do
        service = Rystrix::Service.new(threshold: 0, non_break_count: 0, per: 0.01, size: 10)
        commands = 1000.times.map do
          Rystrix::Command.start(service: service) do
            raise RuntimeError
          end.with_fallback do
            1
          end
        end
        10.times do
          commands.each(&:start)
        end
        sleep 0.1
        command = Rystrix::Command.start(service: service, args: commands) do |*vs|
          vs.inject(:+)
        end
        expect(command.get).to eq(1000)
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
      it 'should be false' do
        command = simple_command(42)
        expect(command.started?).to be false
      end
    end

    context 'with fallback' do
      it 'should be true (both) if the command with no fallback is started' do
        command = simple_command(42)
        fallback_command = command.with_fallback { 0 }
        expect(command.started?).to be false
        expect(fallback_command.started?).to be false
        command.start
        expect(command.started?).to be true
        expect(fallback_command.started?).to be true
      end

      it 'should be true (both) if the command with fallback is started' do
        command = simple_command(42)
        fallback_command = command.with_fallback { 0 }
        expect(command.started?).to be false
        expect(fallback_command.started?).to be false
        fallback_command.start
        expect(command.started?).to be true
        expect(fallback_command.started?).to be true
      end
    end
  end

  describe '#get' do
    context 'with success' do
      it 'should return success value' do
        command = simple_command(42)
        command.start
        expect(command.get).to eq(42)
      end
    end

    context 'with sleep and success' do
      it 'should block and return success value' do
        start = Time.new
        command = sleep_command(0.1, 42)
        command.start
        expect(command.get).to eq(42)
        expect(Time.now - start).to be > 0.1
      end
    end

    context 'with failure' do
      it 'should throw exception' do
        command = error_command(RuntimeError, nil)
        command.start
        expect { command.get }.to raise_error(RuntimeError)
      end

      it 'should throw exception (no deadlock)' do
        command = error_command(Exception, nil)
        command.start
        expect { command.get }.to raise_error(Exception)
      end
    end

    context 'with not started' do
      it 'should throw NotStartedError' do
        command = simple_command(42)
        expect { command.get }.to raise_error(Rystrix::NotStartedError)
      end
    end

    context 'with timeout' do
      it 'should throw TimeoutError' do
        start = Time.now
        command = sleep_command(1, 42, timeout: 0.1)
        command.start
        expect { command.get }.to raise_error(Rystrix::TimeoutError)
        expect(Time.now - start).to be < 0.12
      end
    end
  end

  describe '#with_fallback' do
    it 'should return new command and same normal_future' do
      command = simple_command(42)
      fallback_command = command.with_fallback do
        0
      end
      expect(fallback_command).not_to eq(command)
      # expect(fallback_command.normal_future).to eq(command.normal_future)
    end

    it 'should not block' do
      command = error_command(RuntimeError, nil)
      command.start
      command.wait
      start_time = Time.now
      fallback_command = command.with_fallback do
        sleep 0.1
        0
      end
      expect(Time.now - start_time).to be < 0.1
      expect(fallback_command.get).to eq(0)
    end

    context 'with normal success' do
      it 'should return normal result' do
        command = simple_command(42).with_fallback { 0 }
        command.start
        expect(command.get).to eq(42)
      end
    end
  end

  describe '#wait' do
    context 'with single' do
      it 'should wait execution' do
        start_time = Time.now
        command = sleep_command(0.1, 42)
        command.start
        command.wait
        expect(Time.now - start_time).to be > 0.1
      end
    end

    context 'with fallback' do
      it 'should wait execution' do
        start_time = Time.now
        command = Rystrix::Command.new do
          sleep 0.1
          raise RuntimeError
        end
        command_with_f = command.with_fallback do
          sleep 0.1
          42
        end
        command_with_f.start
        command.wait
        expect(Time.now - start_time).to be_between(0.1, 0.11).inclusive
        command_with_f.wait
        expect(Time.now - start_time).to be_between(0.2, 0.22).inclusive
      end
    end

    context 'with fallback but normal success' do
      it 'should not wait fallback execution' do
        start_time = Time.now
        command = simple_command(42).with_fallback do
          sleep 0.1
          0
        end
        command.start
        command.wait
        expect(Time.now - start_time).to be < 0.1
        expect(command.get).to eq(42)
      end
    end

    context 'with not started' do
      it 'should throw NotStartedError' do
        command = sleep_command(0.1, 42)
        expect { command.wait }.to raise_error(Rystrix::NotStartedError)
      end
    end
  end

  describe '#on_complete' do
    context 'with normal success and without fallback' do
      it 'should run callback with success' do
        command = simple_command(42)
        success = nil
        value = nil
        reason = nil
        command.on_complete do |s, v, r|
          success = s
          value = v
          reason = r
        end
        command.start.wait
        expect(success).to be true
        expect(value).to eq(42)
        expect(reason).to be_nil
      end
    end

    context 'with normal success and with fallback' do
      it 'should run callback with success' do
        command = simple_command(42).with_fallback { 0 }
        success = nil
        value = nil
        reason = nil
        command.on_complete do |s, v, r|
          success = s
          value = v
          reason = r
        end
        command.start.wait
        expect(success).to be true
        expect(value).to eq(42)
        expect(reason).to be_nil
      end
    end

    context 'with normal failure and without fallback' do
      it 'should run callback with failure' do
        command = error_command(RuntimeError, 42)
        success = nil
        value = nil
        reason = nil
        command.on_complete do |s, v, r|
          success = s
          value = v
          reason = r
        end
        command.start.wait
        expect(success).to be false
        expect(value).to be_nil
        expect(reason).to be_instance_of(RuntimeError)
      end
    end

    context 'with normal failure and with fallback success' do
      it 'should run callback with success' do
        command = error_command(RuntimeError, 42).with_fallback { 0 }
        success = nil
        value = nil
        reason = nil
        command.on_complete do |s, v, r|
          success = s
          value = v
          reason = r
        end
        command.start.wait
        expect(success).to be true
        expect(value).to eq(0)
        expect(reason).to be_nil
      end
    end

    context 'with normal failure and with fallback failure' do
      it 'should run callback with failure' do
        command = error_command(RuntimeError, 42).with_fallback do |e|
          raise e
        end
        success = nil
        value = nil
        reason = nil
        command.on_complete do |s, v, r|
          success = s
          value = v
          reason = r
        end
        command.start.wait
        expect(success).to be false
        expect(value).to be_nil
        expect(reason).to be_instance_of(RuntimeError)
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
        command = simple_command(42).with_fallback { 0 }
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
        command = error_command(RuntimeError, 42)
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
        command = error_command(RuntimeError, 42).with_fallback do
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
        command = error_command(RuntimeError, 42).with_fallback do |e|
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
        command = error_command(RuntimeError, 42)
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
        command = simple_command(42).with_fallback do
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
        command = error_command(RuntimeError, 42).with_fallback do
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
        command = error_command(RuntimeError, 42).with_fallback do |e|
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

  describe '.const' do
    it 'should be ok' do
      command = Rystrix::Command.const(42)
      expect(command.started?).to be true
      expect(command.get).to eq(42)
      expect(command.start).to eq(command)
      command_f = command.with_fallback { 0 }
      expect(command_f.get).to eq(42)
      command.wait
    end
  end

  describe '.start' do
    it 'should be already started' do
      command = Rystrix::Command.start do
        sleep 0.1
        42
      end
      start_time = Time.new
      expect(command.started?).to be true
      command.wait
      expect(Time.now - start_time).to be_between(0.1, 0.11)
      expect(command.get).to be 42
    end
  end

  describe 'args function' do
    context 'with normal and no sleep' do
      it 'should be ok' do
        command1 = simple_command('The world of truth is...: ')
        command2 = simple_command(42)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2.to_s
        end
        command3.start
        expect(command3.get).to eq('The world of truth is...: 42')
      end
    end

    context 'with normal and sleep' do
      it 'should start args concurrently' do
        start = Time.now
        command1 = sleep_command(0.1, 1)
        command2 = sleep_command(0.2, 2)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect(command3.get).to eq(3)
        expect(Time.now - start).to be < 0.21
      end
    end

    context 'with failure' do
      it 'should throw error of args' do
        command1 = simple_command(42)
        command2 = error_command(RuntimeError, 42)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect { command3.get }.to raise_error(RuntimeError)
      end
    end

    context 'with sleep and failure' do
      it 'should throw error immediately' do
        start = Time.now
        command1 = sleep_command(0.1, 42)
        command2 = error_command(RuntimeError, 100)
        command3 = Rystrix::Command.new(args: [command1, command2]) do |v1, v2|
          v1 + v2
        end
        command3.start
        expect { command3.get }.to raise_error(RuntimeError)
        expect(Time.now - start).to be < 0.1
      end
    end

    context 'with large number of horizontal dependencies' do
      it 'should be ok' do
        commands = 10000.times.map do
          sleep_command(0.01, 1)
        end
        command = Rystrix::Command.new(args: commands) do |*vs|
          vs.inject(:+)
        end
        command.start
        expect(command.get).to eq(10000)
      end
    end

    context 'with large number of horizontal dependencies ^ 2 (long test case)' do
      it 'should be ok' do
        commands = 300.times.map do
          commands = 300.times.map do
            sleep_command(0.001, 1)
          end
          command = Rystrix::Command.new(args: commands) do |*vs|
            vs.inject(:+)
          end
        end
        command = Rystrix::Command.new(args: commands) do |*vs|
          vs.inject(:+)
        end
        start = Time.now
        command.start
        expect(command.get).to eq(90000)
      end
    end

    context 'with large number of vertical dependencies' do
      it 'should be ok' do
        command0 = simple_command(0)
        command = 1000.times.inject(command0) do |c|
          Rystrix::Command.new(args: [c]) do |v|
            v + 1
          end
        end
        command.start
        expect(command.get).to eq(1000)
      end
    end
  end

  describe 'fallback function' do
    context 'with normal' do
      it 'should be normal value' do
        command = simple_command(42).with_fallback { 0 }
        command.start
        expect(command.get).to eq(42)
      end
    end

    context 'with failure of normal' do
      it 'should be fallback value' do
        command = error_command(RuntimeError, 42).with_fallback { 0 }
        command.start
        expect(command.get).to eq(0)
      end
    end

    context 'with fail both' do
      it 'should throw fallback error' do
        command = error_command(RuntimeError, 42).with_fallback do
          raise Exception
        end
        command.start
        expect { command.get }.to raise_error(Exception)
      end
    end

    context 'with large number of commands' do
      it 'should not throw any errors' do
        service = Rystrix::Service.new(max_threads: 10, min_threads: 10, max_queue: 100)
        commands = 1000.times.map do
          Rystrix::Command.new(service: service) do
            raise RuntimeError
          end.with_fallback do |e|
            1
          end
        end
        commands.each(&:start)
        sum = commands.map(&:get).inject(:+)
        expect(sum).to eq(1000)
        service.shutdown
      end
    end
  end

  describe 'circuit break function' do
    context 'with circuit break' do
      it 'should reject execution' do
        service = Rystrix::Service.new(max_queue: 0, threshold: 0.5, non_break_count: 99, per: 0.01, size: 10)
        commands = 100.times.map do
          Rystrix::Command.new(service: service) do
            raise RuntimeError
          end.with_fallback do |e|
            if e === Rystrix::CircuitBreakError
              1
            else
              0
            end
          end
        end
        commands.each(&:start)
        sum = commands.map(&:get).inject(:+)
        expect(sum).to eq(0)
        command = Rystrix::Command.new(service: service) do
          42
        end
        command.start
        expect { command.get }.to raise_error(Rystrix::CircuitBreakError)
        service.shutdown
      end

      it 'should not count circuit break' do
        service = Rystrix::Service.new(threshold: 0, non_break_count: 0)
        commands = 100.times.map do
          Rystrix::Command.new(service: service) do
            raise Rystrix::CircuitBreakError
          end
        end
        commands.map(&:start)
        commands.map(&:wait)
        command = Rystrix::Command.new(service: service) do
          42
        end
        command.start
        expect(command.get).to eq(42)
        service.shutdown
      end
    end

    context 'with circuit break and wait' do
      it 'should reject execution and back' do
        service = Rystrix::Service.new(threshold: 0.2, non_break_count: 99, per: 0.01, size: 10)
        failure_commands = 20.times.map do
          Rystrix::Command.new(service: service) do
            raise RuntimeError
          end
        end
        success_commands = 80.times.map do
          Rystrix::Command.new(service: service) do
            0
          end
        end

        failure_commands.each(&:start)
        failure_commands.each(&:wait)
        start_time = Time.now
        success_commands.each(&:start)
        success_commands.each(&:wait)
        while true do
          command = Rystrix::Command.new(service: service) do
            42
          end
          command.start
          command.wait
          sleep 0.001
          begin
            command.get
            break
          rescue
          end
        end
        expect(Time.now - start_time).to be_between(0.09, 0.10)
        service.shutdown
      end
    end

    context 'with circuit break (large case)' do
      it 'should be ok' do
        service = Rystrix::Service.new(threshold: 0.2, non_break_count: 9999, per: 0.1, size: 10)
        failure_commands = 2000.times.map do
          Rystrix::Command.new(service: service) do
            raise RuntimeError
          end.with_fallback do
            sleep 0.001
            1
          end
        end
        success_commands = 8000.times.map do
          Rystrix::Command.new(service: service) do
            sleep 0.001
            1
          end
        end
        command = Rystrix::Command.new(
          service: service,
          args: failure_commands + success_commands,
        ) do |*vs|
          vs.inject(:+)
        end.with_fallback { 0 }
        command.start
        expect(command.get).to eq(0)
        service.shutdown
      end
    end
  end

  describe 'entire' do
    context 'with complex example' do
      it 'should be ok' do
        start = Time.now
        command1 = sleep_command(0.1, 1)
        command2 = sleep_command(1000, 'timeout!', timeout: 0.5)
        fallback_command2 = command2.with_fallback do |e|
          2
        end
        command3 = Rystrix::Command.new(args: [command1, fallback_command2]) do |v1, v2|
          sleep 0.2
          v1 + v2 + 4
        end
        command4 = Rystrix::Command.new(args: [command2, command3]) do |v2, v3|
          sleep 0.3
          v2 + v3 + 8
        end
        fallback_command4 = command4.with_fallback do
          8
        end

        fallback_command4.start

        expect(command1.get).to eq(1)
        expect(fallback_command4.get).to eq(8)
        expect(Time.now - start).to be < 0.52

        expect(command1.get).to eq(1)
        expect(fallback_command2.get).to eq(2)
        expect(command3.get).to eq(7)
        expect(Time.now - start).to be < 0.72
      end
    end
  end
end
