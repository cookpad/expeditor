## 0.7.1
- Fix Ruby 2 style keyword arguments to support Ruby 3 [#45](https://github.com/cookpad/expeditor/pull/27)

## 0.7.0
- Add `gem 'concurrent-ruby-ext'` to your Gemfile if you want to use that gem.
    - We should not depend on this in a gemspec [#27](https://github.com/cookpad/expeditor/pull/27)
- Fix possible race conditions.
- Fix bug on cutting passing size [#30](https://github.com/cookpad/expeditor/pull/30)
- Implement sleep feature on circuit breaker [#36](https://github.com/cookpad/expeditor/pull/36)

## 0.6.0
- Improve default configuration of circuit breaker [#25](https://github.com/cookpad/expeditor/pull/25)
  - Default `non_break_count` is reduced from 100 to 20
- Return proper status of service [#26](https://github.com/cookpad/expeditor/pull/26)
  - Use `Expeditor::Service#status` instead of `#current_status`

## 0.5.0
- Add a `current_thread` option of `Expeditor::Command#start` method to execute a task on current thread [#13](https://github.com/cookpad/expeditor/pull/13)
- Drop support for MRI 2.0.x [#15](https://github.com/cookpad/expeditor/pull/15)
- Deprecate Expeditor::Command#with_fallback. Use `set_fallback` instead [#14](https://github.com/cookpad/expeditor/pull/14)
- Do not allow set_fallback call after command is started. [#18](https://github.com/cookpad/expeditor/pull/18)

## 0.4.0
- Add Expeditor::Service#current\_status [#9](https://github.com/cookpad/expeditor/issues/9)
- Add Expeditor::Service#reset\_status! [#10](https://github.com/cookpad/expeditor/issues/10)
- Add Expeditor::Service#fallback\_enabled [#11](https://github.com/cookpad/expeditor/issues/11)

## 0.3.0
- Support concurrent-ruby 1.0.

## 0.2.0
- Support concurrent-ruby 0.9.

## 0.1.1
- Avoid to use concurrent-ruby 0.9.x. #1

## 0.1.0
- First release :tada:
