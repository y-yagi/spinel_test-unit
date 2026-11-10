# frozen_string_literal: true

require "test_helper"
require "stringio"

# Runs the (pure Ruby) runtime on CRuby.
class RuntimeCaseTest < Test::Unit::TestCase
  class Sample < SpinelTest::Unit::TestCase
    attr_reader :log

    def setup
      @log = ["setup"]
    end

    def teardown
      @log << "teardown"
    end

    def test_pass
      assert true
      assert 1 == 1
    end

    def test_fail
      assert false, "nope"
    end

    def test_fail_default_message
      assert nil
    end

    def test_error
      raise "boom"
    end
  end

  def run_tests(filter = "")
    runner = SpinelTest::Unit::Runner.new(filter)
    out = StringIO.new
    $stdout = out
    sample = nil
    %w[test_pass test_fail test_fail_default_message test_error].each do |m|
      sample = Sample.new
      runner.run("Sample##{m}", sample) { sample.send(m) }
    end
    status = runner.finish
    [status, out.string, sample]
  ensure
    $stdout = STDOUT
  end

  def test_counts_and_status
    status, out, = run_tests
    assert_equal 1, status
    assert_include out, ".FFE"
    assert_include out, "4 tests, 4 assertions, 2 failures, 1 errors"
    assert_include out, "nope"
    assert_include out, "Failed assertion, no message given."
    assert_include out, "boom"
  end

  def test_setup_and_teardown_run
    _, _, sample = run_tests
    assert_equal %w[setup teardown], sample.log
  end

  def test_filter
    _, out, = run_tests("test_pass")
    assert_include out, "1 tests, 2 assertions, 0 failures, 0 errors"
  end

  def test_all_passing_returns_zero
    runner = SpinelTest::Unit::Runner.new("")
    s = Sample.new
    $stdout = StringIO.new
    runner.run("Sample#test_pass", s) { s.test_pass }
    assert_equal 0, runner.finish
  ensure
    $stdout = STDOUT
  end

  class Hooks < SpinelTest::Unit::TestCase
    def teardown
      raise "teardown boom"
    end

    def test_fail
      assert false, "first"
    end

    def test_ok
      assert true
    end

    def test_not_implemented
      raise NotImplementedError, "todo"
    end

    def test_exit
      exit 3
    end
  end

  def run_one(name)
    $stdout = out = StringIO.new
    runner = SpinelTest::Unit::Runner.new("")
    t = Hooks.new
    runner.run("Hooks##{name}", t) { t.send(name) }
    runner.finish
    out.string
  ensure
    $stdout = STDOUT
  end

  def test_teardown_error_after_failure_is_appended
    out = run_one("test_fail")
    assert_include out, "1 failures, 0 errors"
    assert_match(/first\n(    at .*\n)+Teardown also raised: teardown boom/, out)
  end

  def test_teardown_error_comes_after_the_location_of_the_failure
    $stdout = out = StringIO.new
    runner = SpinelTest::Unit::Runner.new("")
    t = Hooks.new
    failure = SpinelTest::Unit::AssertionFailedError.new("first")
    failure.set_backtrace([])
    runner.run("Hooks#test_fail", t, "t.rb:9") { raise failure }
    runner.finish
    assert_include out.string, "first\n    at t.rb:9\nTeardown also raised: teardown boom\n"
  ensure
    $stdout = STDOUT
  end

  def test_teardown_error_alone_is_an_error
    out = run_one("test_ok")
    assert_include out, "0 failures, 1 errors"
    assert_include out, "teardown boom"
  end

  def test_script_error_is_reported_not_fatal
    out = run_one("test_not_implemented")
    assert_include out, "1 errors"
    assert_include out, "todo"
  end

  def test_system_exit_is_not_swallowed
    assert_raise(SystemExit) { run_one("test_exit") }
  end

  def test_assert_raise_lets_assertion_failures_propagate
    tc = SpinelTest::Unit::TestCase.new
    [StandardError, ArgumentError, SpinelTest::Unit::AssertionFailedError].each do |klass|
      e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
        tc.assert_raise(klass) { tc.assert_equal 1, 2 }
      end
      assert_equal "Expected: 1\n  Actual: 2", e.message
    end
  end

  def test_assert_raise_still_returns_matching_error
    tc = SpinelTest::Unit::TestCase.new
    e = tc.assert_raise(ArgumentError) { raise ArgumentError, "x" }
    assert_equal "x", e.message
  end

  def test_assert_raise_rejects_a_subclass
    tc = SpinelTest::Unit::TestCase.new
    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise(StandardError) { raise ArgumentError, "x" }
    end
    assert_equal "Expected StandardError but got ArgumentError", e.message
  end

  def test_assert_raise_kind_of_accepts_a_subclass
    tc = SpinelTest::Unit::TestCase.new
    e = tc.assert_raise_kind_of(StandardError) { raise ArgumentError, "x" }
    assert_equal ArgumentError, e.class
    e = tc.assert_raise_kind_of(ArgumentError, match: /x/) { raise ArgumentError, "x" }
    assert_equal "x", e.message
    assert_equal 2, tc.assertions

    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise_kind_of(ArgumentError) { raise TypeError, "t" }
    end
    assert_equal "Expected ArgumentError but got TypeError", e.message
    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise_kind_of(ArgumentError, match: "y") { raise ArgumentError, "x" }
    end
    assert_equal "Expected ArgumentError with a message matching \"y\" but got \"x\"", e.message
    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise_kind_of(ArgumentError) { 1 + 1 }
    end
    assert_equal "Expected ArgumentError but nothing was raised", e.message
  end

  def test_assert_raise_kind_of_lets_assertion_failures_propagate
    tc = SpinelTest::Unit::TestCase.new
    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise_kind_of(StandardError) { tc.assert_equal 1, 2 }
    end
    assert_equal "Expected: 1\n  Actual: 2", e.message
  end

  def test_assert_raise_checks_message
    tc = SpinelTest::Unit::TestCase.new
    e = tc.assert_raise(ArgumentError, match: "bad") { raise ArgumentError, "bad" }
    assert_equal "bad", e.message
    e = tc.assert_raise(ArgumentError, match: "ad") { raise ArgumentError, "bad" }
    assert_equal "bad", e.message
    e = tc.assert_raise(ArgumentError, match: /^ba/) { raise ArgumentError, "bad" }
    assert_equal "bad", e.message

    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise(ArgumentError, match: ".") { raise ArgumentError, "bad" }
    end
    assert_equal "Expected ArgumentError with a message matching \".\" but got \"bad\"", e.message

    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise(ArgumentError, match: /x/) { raise ArgumentError, "bad" }
    end
    assert_equal "Expected ArgumentError with a message matching /x/ but got \"bad\"", e.message

    e = assert_raise(SpinelTest::Unit::AssertionFailedError) do
      tc.assert_raise(ArgumentError, match: "bad") { raise TypeError, "bad" }
    end
    assert_equal "Expected ArgumentError but got TypeError", e.message
  end

  def test_assert_includes_uses_message
    tc = SpinelTest::Unit::TestCase.new
    e = assert_raise(SpinelTest::Unit::AssertionFailedError) { tc.assert_includes [1], 2, "custom" }
    assert_equal "custom\n[1] does not include 2", e.message
  end

  def test_zero_tests_returns_one_with_warning
    $stdout = out = StringIO.new
    status = SpinelTest::Unit::Runner.new("nomatch").finish
    assert_equal 1, status
    assert_include out.string, "0 tests"
    assert_include out.string, "No tests were run"
  ensure
    $stdout = STDOUT
  end

  def failure_message
    yield
    nil
  rescue SpinelTest::Unit::AssertionFailedError => e
    e.message
  end

  def test_assert_equal_adds_a_diff_for_multiline_strings
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal("a\nb", "a\nc") }
    assert_equal "Expected: \"a\\nb\"\n  Actual: \"a\\nc\"\nDiff:\n  a\n- b\n+ c", message
  end

  def test_assert_equal_has_no_diff_for_single_line_strings
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal("a", "b") }
    assert_equal "Expected: \"a\"\n  Actual: \"b\"", message
  end

  def test_assert_equal_has_no_diff_when_only_one_side_is_multiline
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal("a\nb", "a") }
    assert_not_include message, "Diff:"
  end

  def test_assert_match
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.assert_match(/b+/, "abbc")
    assert_true tc.assert_match("bc", "abbc")
    assert_equal 2, tc.assertions
    assert_equal "Expected /x/ to match \"abc\"", failure_message { tc.assert_match(/x/, "abc") }
    assert_equal "Expected \"x\" to match \"abc\"", failure_message { tc.assert_match("x", "abc") }
    assert_equal "hi\nExpected /x/ to match \"abc\"", failure_message { tc.assert_match(/x/, "abc", "hi") }
  end

  def test_assert_not_equal
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.assert_not_equal(1, 2)
    assert_equal "Expected 1 not to equal 1", failure_message { tc.assert_not_equal(1, 1) }
    assert_equal "hi\nExpected 1 not to equal 1", failure_message { tc.assert_not_equal(1, 1, "hi") }
    assert_equal 3, tc.assertions
  end

  def test_assert_not_nil
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.assert_not_nil(false)
    assert_equal "Expected a value other than nil", failure_message { tc.assert_not_nil(nil) }
    assert_equal "hi\nExpected a value other than nil", failure_message { tc.assert_not_nil(nil, "hi") }
    assert_equal 3, tc.assertions
  end

  def test_assert_include
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.assert_include([1], 1)
    assert_equal "[1] does not include 2", failure_message { tc.assert_include([1], 2) }
    assert_equal "hi\n[1] does not include 2", failure_message { tc.assert_include([1], 2, "hi") }
    assert_equal 3, tc.assertions
  end

  def test_assert_includes_is_an_alias_of_assert_include
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.assert_includes([1], 1)
    assert_equal "[1] does not include 2", failure_message { tc.assert_includes([1], 2) }
    assert_equal 2, tc.assertions
  end

  def test_assert_not_include
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.assert_not_include([1], 2)
    assert_equal "[1, 2] includes 2", failure_message { tc.assert_not_include([1, 2], 2) }
    assert_equal "hi\n[1, 2] includes 2", failure_message { tc.assert_not_include([1, 2], 2, "hi") }
    assert_equal 3, tc.assertions
  end

  def test_refute
    tc = SpinelTest::Unit::TestCase.new
    assert_true tc.refute(nil)
    assert_equal "Failed refutation, no message given.", failure_message { tc.refute(true) }
    assert_equal "hi", failure_message { tc.refute(1, "hi") }
    assert_equal 3, tc.assertions
  end

  def report_for(name, location, &block)
    runner = SpinelTest::Unit::Runner.new
    out = StringIO.new
    $stdout = out
    runner.run(name, SpinelTest::Unit::TestCase.new, location, &block)
    runner.finish
    out.string
  ensure
    $stdout = STDOUT
  end

  def raise_in_helper
    raise "deep"
  end

  def test_report_shows_framework_free_backtrace_frames
    out = report_for("T#test_x", "t.rb:1") { raise_in_helper }
    lines = out.lines.map(&:chomp)
    at = lines.select { |line| line.start_with?("    at ") }
    assert_operator at.size, :<=, SpinelTest::Unit::Runner::MAX_FRAMES
    assert_match(/\A    at .*test_case_test\.rb:\d+\z/, at.first)
    assert_not_include out, "/lib/spinel_test/unit/"
    assert_not_include out, "    at t.rb:1\n"
  end

  def test_report_falls_back_to_the_test_location_without_a_backtrace
    error = RuntimeError.new("boom")
    error.set_backtrace([])
    out = report_for("T#test_x", "t.rb:1") { raise error }
    assert_include out, "Error: T#test_x\nboom\n    at t.rb:1\n"
  end

  def test_report_has_no_location_line_when_nothing_is_known
    error = RuntimeError.new("boom")
    error.set_backtrace([])
    out = report_for("T#test_x", "") { raise error }
    assert_not_include out, "    at "
  end

  def test_assert_match_fails_for_a_subject_that_is_not_a_string
    tc = SpinelTest::Unit::TestCase.new
    assert_equal "Expected /a/ to match nil", failure_message { tc.assert_match(/a/, nil) }
    assert_equal "Expected \"a\" to match nil", failure_message { tc.assert_match("a", nil) }
    assert_equal "Expected /1/ to match 1", failure_message { tc.assert_match(/1/, 1) }
  end

  def test_assert_equal_skips_the_diff_for_huge_differences
    expected = (1..1200).map { |n| "e#{n}" }.join("\n")
    actual = (1..1200).map { |n| "a#{n}" }.join("\n")
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal(expected, actual) }
    assert_include message, "Diff:\n  (diff skipped: 1200 expected and 1200 actual lines differ)"
  end

  def test_assert_equal_puts_the_message_before_expected_actual_and_diff
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal("a\nb", "a\nc", "custom") }
    assert_equal "custom\nExpected: \"a\\nb\"\n  Actual: \"a\\nc\"\nDiff:\n  a\n- b\n+ c", message
  end

  def test_assert_equal_still_fails_without_a_diff_for_invalid_utf8
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal("\xff\nb", "a\nb") }
    assert_include message, "Expected:"
    assert_not_include message, "Diff:"
  end

  def test_assert_equal_still_fails_without_a_diff_for_mixed_encodings
    message = failure_message { SpinelTest::Unit::TestCase.new.assert_equal("é\nb".b, "é\nc") }
    assert_include message, "Expected:"
    assert_not_include message, "Diff:"
  end

  def test_errors_are_reported_where_they_were_raised
    runner = SpinelTest::Unit::Runner.new("", "/proj")
    error = ArgumentError.new("x")
    error.set_backtrace(["/proj/test/a_test.rb:3:in 'helper'", "/proj/test/a_test.rb:3:in 'Array#each'",
                         "/proj/test/a_test.rb:3:in 'Integer#times'", "/proj/test/a_test.rb:8:in 'test_a'",
                         "/proj/test/a_test.rb:20:in 'run'", "/other/file.rb:1:in 'x'"])
    assert_equal ["test/a_test.rb:3", "test/a_test.rb:8", "test/a_test.rb:20"], runner.report_frames(error, "test/a_test.rb:7")
  end

  def test_frames_inside_the_framework_are_left_out
    runner = SpinelTest::Unit::Runner.new("", "/proj")
    error = ArgumentError.new("x")
    error.set_backtrace(["#{SpinelTest::Unit::Runner::FRAMEWORK_DIR}test_case.rb:1:in 'assert'", "/proj/t.rb:2:in 'test_a'"])
    assert_equal ["t.rb:2"], runner.report_frames(error, "t.rb:1")
  end

  def test_the_first_frame_is_kept_even_outside_the_root
    runner = SpinelTest::Unit::Runner.new("", "/proj")
    error = ArgumentError.new("x")
    error.set_backtrace(["/gems/uri/uri.rb:9:in 'parse'", "/gems/uri/uri.rb:20:in 'join'",
                         "/proj/test/a_test.rb:5:in 'test_a'", "/gems/minitest.rb:1:in 'run'",
                         "/proj/test/a_test.rb:30:in 'run'"])
    assert_equal ["/gems/uri/uri.rb:9", "test/a_test.rb:5", "test/a_test.rb:30"], runner.report_frames(error, "test/a_test.rb:4")
  end

  def test_every_frame_counts_without_a_root
    runner = SpinelTest::Unit::Runner.new("")
    error = ArgumentError.new("x")
    error.set_backtrace(["/gems/a.rb:1:in 'x'", "/other/b.rb:2:in 'y'"])
    assert_equal ["/gems/a.rb:1", "/other/b.rb:2"], runner.report_frames(error, "t.rb:1")
  end

  class NoBacktraceError < StandardError
    def backtrace
      nil
    end
  end

  def test_an_exception_without_a_backtrace_uses_the_test_location
    runner = SpinelTest::Unit::Runner.new("", "/proj")
    assert_equal ["t.rb:1"], runner.report_frames(NoBacktraceError.new("x"), "t.rb:1")
  end

  def test_the_test_location_is_used_without_a_backtrace
    runner = SpinelTest::Unit::Runner.new("", "/proj")
    error = ArgumentError.new("x")
    error.set_backtrace([])
    assert_equal ["t.rb:1"], runner.report_frames(error, "t.rb:1")
  end

  def test_error_raised_only_in_teardown_gets_a_location
    $stdout = out = StringIO.new
    runner = SpinelTest::Unit::Runner.new("")
    t = Hooks.new
    runner.run("Hooks#test_ok", t, "t.rb:9") { t.test_ok }
    runner.finish
    assert_include out.string, "Error: Hooks#test_ok\nteardown boom\n    at "
  ensure
    $stdout = STDOUT
  end
end
