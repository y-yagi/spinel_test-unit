# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

# End to end: CLI -> Spinel -> binary. Skipped when Spinel is not available.
class CLITest < Test::Unit::TestCase
  EXE = File.expand_path("../../../exe/spinel_test-unit", __dir__)
  FIXTURES = File.expand_path("../../fixtures", __dir__)

  def setup
    return if SpinelTest::Unit::Toolchain.spinel

    flunk "Spinel not found (required when CI is set)" if ENV["CI"]
    omit "Spinel not found"
  end

  def run_cli(*args, chdir: File.expand_path("../../..", __dir__))
    Open3.capture3(RbConfig.ruby, EXE, *args, chdir: chdir)
  end

  def write(root, rel, content)
    path = File.join(root, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def test_passing_fixture_exits_zero
    out, err, status = run_cli(File.join(FIXTURES, "passing"))
    assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
    assert_include out, "6 tests, 13 assertions, 0 failures, 0 errors"
  end

  def test_failing_fixture_exits_one
    out, _err, status = run_cli(File.join(FIXTURES, "failing"))
    assert_equal 1, status.exitstatus
    assert_include out, "13 tests, 12 assertions, 11 failures, 1 errors"
    assert_include out, "Failure: BrokenTest#test_failure"
    assert_include out, "math is broken"
    assert_include out, "Error: BrokenTest#test_error"
    assert_include out, "boom"
  end

  def test_assertion_failure_messages
    out, _err, status = run_cli(File.join(FIXTURES, "failing"), "-n", "AssertionFailuresTest")
    assert_equal 1, status.exitstatus
    assert_include out, "10 tests, 10 assertions, 10 failures, 0 errors"
    assert_include out, "Failure: AssertionFailuresTest#test_equal_ints\nExpected: 1\n  Actual: 2"
    assert_include out, "custom equal\nExpected: 1\n  Actual: 2"
    assert_include out, "Expected: 1\n  Actual: nil"
    assert_include out, "Expected: \"1\"\n  Actual: 1"
    assert_include out, "Expected: 1\n  Actual: 1.5"
    assert_include out, "Expected nil, got 42"
    assert_include out, "custom nil\nExpected nil, got \"x\""
    assert_include out, "[1, 2] does not include 3"
    assert_include out, "Expected ArgumentError but got TypeError"
    assert_include out, "Expected ArgumentError but nothing was raised"
  end

  def test_name_filter
    out, _err, status = run_cli(File.join(FIXTURES, "failing"), "-n", "test_ok")
    assert_true status.success?
    assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
  end

  def test_no_match_filter_exits_one
    out, _err, status = run_cli(File.join(FIXTURES, "passing"), "-n", "nomatch_zzz")
    assert_equal 1, status.exitstatus
    assert_include out, "0 tests"
  end

  def test_project_without_lib_dir
    Dir.mktmpdir do |root|
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        class ATest < SpinelTest::Unit::TestCase
          def test_a
            assert true
          end
        end
      RUBY
      out, err, status = run_cli(chdir: root)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
    end
  end

  def test_inherits_base_class_from_other_file
    Dir.mktmpdir do |root|
      write(root, "test/base_helper.rb", <<~RUBY)
        require "spinel_test/unit"
        class BaseHelper < SpinelTest::Unit::TestCase
          def test_inherited
            assert true
          end
        end
      RUBY
      write(root, "test/c_test.rb", <<~RUBY)
        require "base_helper"
        class CTest < BaseHelper
          def test_own
            assert true
          end
        end
      RUBY
      out, err, status = run_cli(chdir: root)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "2 tests, 2 assertions, 0 failures, 0 errors"
    end
  end

  def test_unresolved_parent_warns
    Dir.mktmpdir do |root|
      write(root, "test/x_test.rb", "class XTest < Mystery\n  def test_a; end\nend\n")
      _out, err, status = run_cli(chdir: root)
      assert_equal 1, status.exitstatus
      assert_include err, "XTest inherits from Mystery"
    end
  end

  def test_help
    out, _err, status = run_cli("--help")
    assert_true status.success?
    assert_include out, "Usage: spinel_test-unit"
  end

  def test_missing_name_value
    _out, err, status = run_cli("-n")
    assert_equal 2, status.exitstatus
    assert_include err, "-n requires a value"
  end

  def test_unknown_option
    _out, err, status = run_cli("--bogus")
    assert_equal 2, status.exitstatus
    assert_include err, "unknown option: --bogus"
  end

  def test_inherits_base_class_from_include_dir_library
    root = File.join(FIXTURES, "library_base")
    out, err, status = run_cli("-I", "extlib", chdir: root)
    assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
    assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
  end

  def test_library_base_requires_follow_cycles_and_missing_files
    Dir.mktmpdir do |root|
      write(root, "ext/lib_a.rb", "require \"lib_b\"\nrequire \"nonexistent_zzz\"\nrequire \"spinel_test/unit\"\nclass LibA < SpinelTest::Unit::TestCase\nend\n")
      write(root, "ext/lib_b.rb", "require \"lib_a\"\nclass LibB < LibA\n  def test_b; assert true; end\nend\n")
      write(root, "test/t_test.rb", "require \"lib_b\"\nclass TTest < LibB\n  def test_t; assert true; end\nend\n")
      out, err, status = run_cli("-I", "ext", chdir: root)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "2 tests, 2 assertions, 0 failures, 0 errors"
    end
  end

  def test_unresolved_parent_still_warns_with_include_dir
    Dir.mktmpdir do |root|
      write(root, "ext/other.rb", "class Other; end\n")
      write(root, "test/x_test.rb", "require \"other\"\nclass XTest < Mystery\n  def test_a; end\nend\n")
      _out, err, status = run_cli("-I", "ext", chdir: root)
      assert_equal 1, status.exitstatus
      assert_include err, "XTest inherits from Mystery"
    end
  end

  def test_project_inside_a_fixtures_directory
    Dir.mktmpdir do |tmp|
      root = File.join(tmp, "fixtures", "proj")
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        class ATest < SpinelTest::Unit::TestCase
          def test_a
            assert true
          end
        end
      RUBY
      write(root, "test/fixtures/skipped_test.rb", "class SkippedTest < SpinelTest::Unit::TestCase\n  def test_s; end\nend\n")
      out, err, status = run_cli(chdir: root)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
    end
  end

  def test_class_reopened_in_earlier_non_target_file
    Dir.mktmpdir do |root|
      write(root, "test/a_base.rb", <<~RUBY)
        require "spinel_test/unit"
        class FooTest < SpinelTest::Unit::TestCase
          def test_early
            assert true
          end
        end
      RUBY
      write(root, "test/foo_test.rb", <<~RUBY)
        require "a_base"
        class FooTest
          def test_late
            assert true
          end
        end
      RUBY
      out, err, status = run_cli("test/foo_test.rb", chdir: root)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "2 tests, 2 assertions, 0 failures, 0 errors"
    end
  end

  def test_namespaced_base_defined_in_later_file
    Dir.mktmpdir do |root|
      write(root, "test/a_test.rb", <<~RUBY)
        require "z_base"
        module M
          class T < Base
            def test_t
              assert true
            end
          end
        end
      RUBY
      write(root, "test/z_base.rb", <<~RUBY)
        require "spinel_test/unit"
        module M
          class Base < SpinelTest::Unit::TestCase
            def test_base
              assert true
            end
          end
        end
      RUBY
      out, err, status = run_cli("test/a_test.rb", chdir: root)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "2 tests, 2 assertions, 0 failures, 0 errors"
    end
  end

  def test_assert_raise_does_not_swallow_assertion_failures
    Dir.mktmpdir do |root|
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        class ATest < SpinelTest::Unit::TestCase
          def test_std
            assert_raise(StandardError) { assert_equal 1, 2 }
          end

          def test_other
            assert_raise(ArgumentError) { assert_equal 1, 2 }
          end

          def test_includes
            assert_includes [1], 2, "custom inc"
          end
        end
      RUBY
      out, _err, status = run_cli(chdir: root)
      assert_equal 1, status.exitstatus
      assert_include out, "3 tests, 5 assertions, 3 failures, 0 errors"
      assert_include out, "Expected: 1\n  Actual: 2"
      assert_not_include out, "but got"
      assert_include out, "custom inc\n[1] does not include 2"
    end
  end

  def test_script_error_and_teardown_error_are_reported
    Dir.mktmpdir do |root|
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        class ATest < SpinelTest::Unit::TestCase
          def teardown
            raise "td boom"
          end

          def test_a_fail
            assert false, "first"
          end

          def test_b_todo
            raise NotImplementedError, "todo"
          end
        end

        class BTest < SpinelTest::Unit::TestCase
          def test_c_ok
            assert true
          end
        end
      RUBY
      out, err, status = run_cli(chdir: root)
      assert_equal 1, status.exitstatus, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "3 tests, 2 assertions, 1 failures, 1 errors"
      assert_include out, "first\nTeardown also raised: td boom"
      assert_include out, "todo"
    end
  end

  def test_compile_failure_shows_compiler_output
    Dir.mktmpdir do |root|
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        class ATest < SpinelTest::Unit::TestCase
          def test_a
            assert true
          end
        end
        def broken(
      RUBY
      out, err, status = run_cli(chdir: root)
      assert_equal 1, status.exitstatus
      assert_include err, "parse failed"
      assert_include err, "compilation failed"
      assert_false out.include?("tests,")
    end
  end
end
