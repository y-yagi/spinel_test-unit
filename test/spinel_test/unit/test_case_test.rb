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
    assert_include out, "first\nTeardown also raised: teardown boom"
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
    e = tc.assert_raise(StandardError) { raise ArgumentError, "x" }
    assert_equal "x", e.message
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

  def test_assert_match_fails_for_a_subject_that_is_not_a_string
    tc = SpinelTest::Unit::TestCase.new
    assert_equal "Expected /a/ to match nil", failure_message { tc.assert_match(/a/, nil) }
    assert_equal "Expected \"a\" to match nil", failure_message { tc.assert_match("a", nil) }
    assert_equal "Expected /1/ to match 1", failure_message { tc.assert_match(/1/, 1) }
  end
end
