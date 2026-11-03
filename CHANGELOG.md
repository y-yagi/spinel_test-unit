## Unreleased

* Report where a test failed: `at file:line` lines after the message (the test method's line with Spinel, the filtered backtrace with `--ruby`)
* Show a line diff when `assert_equal` fails on two multi-line Strings
* Add `assert_match`, `assert_not_equal`, `assert_not_nil`, `assert_include`, `assert_not_include` and `refute`. `assert_includes` remains as an alias of `assert_include`
* Add `--ruby` to run the tests with the current Ruby instead of compiling them with Spinel

## 0.1.2

* Exclude mise.toml from the gem

## 0.1.1

* Allow to configure Spinel compile options

## 0.1.0

* Initial release
