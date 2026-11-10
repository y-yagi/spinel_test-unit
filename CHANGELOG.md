## Unreleased

* Add `match:` to `assert_raise` to check the exception message, as in `assert_match` (a Regexp, or a String meaning a substring)
* `assert_raise` passes only for the given class itself, not a subclass, as in test-unit. Use the new `assert_raise_kind_of` to also accept a subclass
* Add `-t`/`--testcase CLASS` to run only the tests of the class named exactly CLASS (`-n FooTest#` also selects `MyFooTest`)
* `-n` and `-t` take a regexp written as `/regexp/`, as in test-unit

## 0.2.0

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
