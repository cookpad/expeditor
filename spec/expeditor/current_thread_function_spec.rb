require 'spec_helper'

describe Expeditor::Command do
  let(:error_in_command) { Class.new(StandardError) }

  describe '#start' do
    context 'with normal' do
      it 'should execute on current thread' do
        Thread.current.thread_variable_set('foo', 'bar')
        command = Expeditor::Command.new do
          Thread.current.thread_variable_get('foo')
        end
        expect(command.start(current_thread: true).get).to eq('bar')
      end

      it 'should return self' do
        command = simple_command(42)
        expect(command.start(current_thread: true)).to eq(command)
      end

      it 'should ignore from the second time' do
        count = 0
        command = Expeditor::Command.new do
          count += 1
          count
        end
        command.start(current_thread: true)
        command.start(current_thread: true)
        command.start(current_thread: true)
        expect(command.get).to eq(1)
        expect(count).to eq(1)
      end
    end

    context 'with fallback' do
      it 'should work fallback proc' do
        command = error_command(error_in_command)
        command.set_fallback do
          42
        end

        expect(command.start(current_thread: true).get).to eq(42)
      end

      it 'should work fallback on current thread' do
        Thread.current.thread_variable_set("count", 1)
        command = Expeditor::Command.new do
          count = Thread.current.thread_variable_get("count")
          count += 1
          Thread.current.thread_variable_set("count", count) # => 2
          raise error_in_command
        end

        command.set_fallback do
          count = Thread.current.thread_variable_get("count")
          count += 1
          count # => 3
        end

        expect(command.start(current_thread: true).get).to eq(3)
      end
    end

    context 'explicitly specify `current_thread: false`' do
      it 'should be asynchronous' do
        command = sleep_command(0.2, nil)
        start_time = Time.now
        command.start(current_thread: false)
        expect(Time.now - start_time).to be < 0.2
      end

      it 'should not execute on current thread' do
        Thread.current.thread_variable_set('foo', 1)
        command = Expeditor::Command.new do
          Thread.current.thread_variable_get('foo')
        end
        command.start(current_thread: false)
        expect(command.get).to eq nil
      end
    end
  end

  describe '#start_with_retry' do
    context 'with 3 tries' do
      it 'should execute 3 times on current thread' do
        Thread.current.thread_variable_set('count', 0)
        command = Expeditor::Command.new do
          count = Thread.current.thread_variable_get('count')
          count += 1
          Thread.current.thread_variable_set('count', count)
          raise RuntimeError
        end
        command.start_with_retry(tries: 3, sleep: 0, current_thread: true)
        expect { command.get }.to raise_error(RuntimeError)
        expect(Thread.current.thread_variable_get('count')).to eq 3
      end
    end

    context 'explicitly specify `current_thread: false`' do
      it 'should be asynchronous' do
        command = sleep_command(0.2, nil)
        start_time = Time.now
        command.start_with_retry(current_thread: false)
        expect(Time.now - start_time).to be < 0.2
      end

      it 'should not execute on current thread' do
        Thread.current.thread_variable_set('foo', 1)
        command = Expeditor::Command.new do
          Thread.current.thread_variable_get('foo')
        end
        command.start_with_retry(current_thread: false)
        expect(command.get).to eq nil
      end
    end
  end
end
