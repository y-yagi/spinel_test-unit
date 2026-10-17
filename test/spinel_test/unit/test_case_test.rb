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
end
