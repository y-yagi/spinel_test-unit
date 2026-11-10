# SpinelTest::Unit

An xUnit-style test framework for [Spinel](https://github.com/matz/spinel).

## Installation

Add it to your Gemfile:

```ruby
gem "spinel_test-unit"
```

Spinel itself is found through, in order: the `SPINEL` environment variable,
`spinel` on `PATH`, `mise which spinel`.

## Usage

```ruby
# test/calc_test.rb
require "spinel_test/unit"
require "calc"

class CalcTest < SpinelTest::Unit::TestCase
  def setup
    @calc = Calc.new
  end

  def test_add
    assert @calc.add(1, 2) == 3
  end

  def test_failure_message
    assert @calc.add(1, 1) == 2, "1 + 1 should be 2"
  end
end
```

```console
$ bundle exec spinel_test-unit                 # test/**/*_test.rb and test/**/test_*.rb
$ bundle exec spinel_test-unit test/calc_test.rb
$ bundle exec spinel_test-unit -n test_add     # only tests whose "Class#method" name includes it
$ bundle exec spinel_test-unit -n '/#test_add\z/'  # or matches the regexp
$ bundle exec spinel_test-unit -t CalcTest     # only the tests of the class named exactly CalcTest
$ bundle exec spinel_test-unit -t '/\ACalc/'   # or of the classes whose name matches the regexp
$ bundle exec spinel_test-unit --ruby          # run the same tests with the current Ruby, no Spinel needed
```

`--ruby` runs the generated main.rb with the Ruby that runs the CLI, with the same load paths (`-I`, `lib`, `test`, the project root) instead of compiling it; the child also inherits `RUBYOPT` and `RUBYLIB` (e.g. `bundler/setup`), so it may resolve requires that Spinel cannot. Use it to check that code which must work under both CRuby and Spinel behaves the same in each. The same tests run, with the same report format and exit status convention, but results can differ where CRuby and Spinel differ: Spinel freezes string literals (so `s = "a"; s << "b"` raises under Spinel but passes under `--ruby`), and exception messages can be worded differently.

Output when compiled with Spinel:

```
.F

Failure: CalcTest#test_failure_message
1 + 1 should be 2
    at test/calc_test.rb:14

2 tests, 2 assertions, 1 failures, 0 errors
```

Each failure or error is `Failure: Class#test_name` or `Error: Class#test_name`, the message, and up to three `    at file:line` lines (paths relative to the project root):

- Compiled with Spinel, exceptions have no backtrace, so there is one line: the `file:line` of the test method's `def`.
- With `--ruby`, the lines are the backtrace entries outside this gem and the generated main.rb, so they point at the failing assertion in the test and the callers above it (a test helper, for example). The first entry is always kept, even from outside the project root (an exception raised inside another library shows where); after it only entries under the root are listed. A location equal to the previous line is left out (Ruby 4.0 attributes block-taking builtins such as `Array#each` to their caller's line). If nothing is left after filtering, it falls back to the test method's line.
- An error raised in `setup`, or in `teardown` when the test itself passed, is reported with the same lines (under Spinel, the test method's `def`).
- If a test method is defined more than once, the location of the last definition is used.

When `assert_equal` fails on two Strings that both contain a newline, a line diff follows the Expected/Actual lines. `-` lines are only in the expected string, `+` lines only in the actual one, and unchanged lines more than two away from a change are collapsed into `...`. A single hidden line is shown as is. Lines that could be misread (empty, containing `\r`, starting with `"`, equal to `...`, or starting or ending with a space or tab) are shown with `inspect` (`- ""`, `- "a\r"`). Example:

```
Failure: HttpTest#test_to_cgi
Expected: "a\nb\nc\nd\ne\nf"
  Actual: "a\nb\nX\nd\ne\nf"
Diff:
  a
  b
- c
+ X
  d
  e
  f
    at test/http_test.rb:7
```

Very large differences are not diffed: when the lines between the common start and end of the two strings would need a table of over a million cells, the diff is replaced by a one-line note and the Expected/Actual lines remain.

Available assertions:

- `assert(test, message = nil)`
- `assert_equal(expected, actual, message = nil)`
- `assert_not_equal(expected, actual, message = nil)`
- `assert_nil(value, message = nil)`
- `assert_not_nil(value, message = nil)`
- `assert_match(pattern, string, message = nil)` (`pattern` is a Regexp, or a String meaning a substring, and anything else is reported as an error; a `string` that is not a String, such as `nil`, fails)
- `assert_include(collection, item, message = nil)` (`assert_includes` is an alias)
- `assert_not_include(collection, item, message = nil)`
- `refute(test, message = nil)`
- `assert_raise(klass, match: nil) { ... }` (passes for `klass` itself, not a subclass, as in test-unit; returns the exception; assertion failures raised inside the block propagate). With `match:`, the exception's message must also match it, as in `assert_match` (a Regexp, or a String meaning a substring)
- `assert_raise_kind_of(klass, match: nil) { ... }` (as `assert_raise`, but also passes for a subclass of `klass`)

`setup` and `teardown` hooks are supported.

## Compile speed

The tests are compiled for build speed, not run speed: with `-O0`, and the generated C split into parallel units (Spinel's `--jobs`). Most of a Spinel build is the C compile, so this cuts it several times over. Two environment variables change it:

- `SPINEL_TEST_UNIT_OPT` -- the C optimization level (default `0`). Set `2` to test the binary the way a release build compiles it.
- `SPINEL_TEST_UNIT_JOBS` -- how many units the C is compiled as (default: the number of CPUs, up to 16). `1` compiles it as a single unit. The CPUs counted are the ones the process may use: a cgroup CPU quota (a container started with `--cpus`, for example) counts, not only the host's cores.

## Constraints (from Spinel)

- Test code must be compilable by Spinel: no `send` with dynamic names,
  `define_method`, `instance_methods`, etc. in tests or in the code under test.
- Test classes must be defined as literal `class FooTest < SpinelTest::Unit::TestCase`
  (or a literal subclass of another test class) with literal `def test_*`.
  Tests are never generated by metaprogramming.
- A base test class may live in a library on an `-I` path: `require` /
  `require_relative` with string literals are followed transitively from the
  test files, and those files are scanned (not run) to resolve superclasses.
  Only classes in the target test files are run.
- Files are loaded with `require` and the load paths `lib`, `test` and the
  project root; use `require "..."` / `require_relative` that Spinel resolves.
- Test files under `fixtures/` directories (relative to the project root) are skipped unless named explicitly or the given directory is itself inside `fixtures/`.
- A method parameter is typed from all of its call sites, so mixing a nil-typed local and, say, an Integer in calls to the same assertion can fail to compile or raise at run time under Spinel. For example, `refute 0` together with `n = nil; refute n` in the test files compiled together fails at run time ("nil can't be coerced into Integer") while `--ruby` passes. Keep the arguments of one assertion to one type across those files.
- `ScriptError`s (such as `NotImplementedError`) raised by a test are reported as errors; a teardown error after a failure is appended to its message.

## Development

Run `bin/setup` (installs Spinel with [mise](https://mise.jdx.dev/) and the
gems), then `bundle exec rake test`. The tests use test-unit; the end-to-end
tests are skipped when Spinel is not available. To use a Spinel checkout, set
`SPINEL` in a git-ignored `mise.local.toml`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
