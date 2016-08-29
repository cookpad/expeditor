<!-- ## Master (unreleased) -->

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
