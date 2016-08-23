# Expeditor
[![Gem Version](https://badge.fury.io/rb/expeditor.svg)](http://badge.fury.io/rb/expeditor)
[![Build Status](https://travis-ci.org/cookpad/expeditor.svg?branch=master)](https://travis-ci.org/cookpad/expeditor)

Expeditor is a Ruby library that provides asynchronous execution and fault tolerance for microservices.

It is inspired by [Netflix/Hystrix](https://github.com/Netflix/Hystrix).

## Installation

Expeditor currently supports Ruby 2.1 and higher.

Add this line to your application's Gemfile:

```ruby
gem 'expeditor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install expeditor

## Usage

### asynchronous execution

```ruby
command1 = Expeditor::Command.new do
  ...
end

command2 = Expeditor::Command.new do
  ...
end

command1.start # non blocking
command2.start # non blocking

command1.get   # wait until command1 execution is finished and get the result
command2.get   # wait until command2 execution is finished and get the result
```

### asynchronous execution with dependencies

```ruby
command1 = Expeditor::Command.new do
  ...
end

command2 = Expeditor::Command.new do
  ...
end

command3 = Expeditor::Command.new(dependencies: [command1, command2]) do |val1, val2|
  ...
end

command3.start # command1 and command2 are started concurrently, execution of command3 is wait until command1 and command2 are finished.
```

### fallback

```ruby
command = Expeditor::Command.new do
  # something that may be failed
end

# use fallback value if command is failed
command_with_fallback = command.set_fallback do |e|
  log(e)
  default_value
end

command.start.get #=> error may be raised
command_with_fallback.start.get #=> default_value if command is failed
```

If you set `false` to `Expeditor::Service#fallback_enabled`, fallbacks do not occur. It is useful in test codes.

### timeout

```ruby
command = Expeditor::Command.new(timeout: 1) do
  ...
end

command.start
command.get #=> Timeout::Error is raised if execution is timed out
```

### retry

```ruby
command = Expeditor::Command.new do
  ...
end

# the option is completely same as retryable gem
command.start_with_retry(
  tries: 3,
  sleep: 1,
  on: [StandardError],
)
```

### using thread pool

Expeditor use [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby/)'s executors as thread pool.

```ruby
require 'concurrent'

service = Expeditor::Service.new(
  executor: Concurrent::ThreadPoolExecutor.new(
    min_threads: 0,
    max_threads: 5,
    max_queue: 100,
  )
)

command = Expeditor::Command.new(service: service) do
  ...
end

service.current_status
# => #<Expeditor::Status:0x007fdeeeb18468 @break=0, @dependency=0, @failure=0, @rejection=0, @success=0, @timeout=0>

service.reset_status!  # reset status in the service
```

### circuit breaker

```ruby
service = Expeditor::Service.new(
  period: 10,          # retention period of the service metrics (success, failure, timeout, ...)
  sleep: 1,            # if once the circuit is opened, the circuit is still open until sleep time is passed even though failure rate is less than threshold
  threshold: 0.5,      # if the failure rate is more than or equal to threshold, the circuit is opened
  non_break_count: 100 # if the total count of metrics is not more than non_break_count, the circuit is not opened even though failure rate is more than threshold
)

command = Expeditor::Command.new(service: service) do
  ...
end
```

### synchronous execution

Use `Expeditor::Command#run` instead of `#start`, Command executes synchronous on current thread.

```ruby
command1 = Expeditor::Command.new do
  ...
end

command2 = Expeditor::Command.new do
  ...
end

command1.run # blocking
command2.run # blocking

command1.get
command2.get
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/cookpad/expeditor/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
