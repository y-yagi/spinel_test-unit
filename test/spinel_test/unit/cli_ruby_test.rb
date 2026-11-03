# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

class CLIRubyTest < Test::Unit::TestCase
  EXE = File.expand_path("../../../exe/spinel_test-unit", __dir__)
  FIXTURES = File.expand_path("../../fixtures", __dir__)
  PATH_WITHOUT_SPINEL = ENV["PATH"].split(File::PATH_SEPARATOR).reject do |dir|
    %w[spinel mise].any? { |name| File.executable?(File.join(dir, name)) }
  end.join(File::PATH_SEPARATOR)
  NO_SPINEL_ENV = { "SPINEL" => nil, "PATH" => PATH_WITHOUT_SPINEL }.freeze

  def run_cli(*args)
    Open3.capture3(NO_SPINEL_ENV, RbConfig.ruby, EXE, "--ruby", *args, chdir: File.expand_path("../../..", __dir__))
  end

  def write_test_project(root, body)
    write(root, "test/a_test.rb", <<~RUBY)
      require "spinel_test/unit"
      class ATest < SpinelTest::Unit::TestCase
        def test_it
          #{body}
        end
      end
    RUBY
    File.join(root, "test")
  end

  def write(root, relative_path, content)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def test_passing_fixture_exits_zero
    out, err, status = run_cli(File.join(FIXTURES, "passing"))
    assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
    assert_include out, "6 tests, 13 assertions, 0 failures, 0 errors"
    assert_equal "", err
  end

  def test_spinel_is_unreachable_without_ruby_option
    _out, err, status = Open3.capture3(NO_SPINEL_ENV, RbConfig.ruby, EXE, File.join(FIXTURES, "passing"),
                                       chdir: File.expand_path("../../..", __dir__))
    assert_equal 1, status.exitstatus
    assert_include err, "Spinel not found"
  end

  def test_failing_fixture_reports_each_case
    out, _err, status = run_cli(File.join(FIXTURES, "failing"), "-n", "BrokenTest")
    assert_equal 1, status.exitstatus
    assert_include out, "3 tests, 2 assertions, 1 failures, 1 errors"
    assert_include out, "Failure: BrokenTest#test_failure\nmath is broken"
    assert_include out, "Error: BrokenTest#test_error\nboom"
  end

  def test_name_filter
    out, _err, status = run_cli(File.join(FIXTURES, "failing"), "-n", "test_ok")
    assert_true status.success?
    assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
  end

  def test_include_dirs_are_on_the_load_path
    Dir.mktmpdir do |root|
      write(root, "extlib/shared_helper.rb", "SHARED_VALUE = 42\n")
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        require "shared_helper"
        class ATest < SpinelTest::Unit::TestCase
          def test_shared
            assert_equal 42, SHARED_VALUE
          end
        end
      RUBY
      out, err, status = run_cli("-I", File.join(root, "extlib"), File.join(root, "test"))
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
    end
  end

  def test_tests_run_on_cruby
    Dir.mktmpdir do |root|
      dir = write_test_project(root, 'assert_equal "ruby", RUBY_ENGINE')
      out, err, status = run_cli(dir)
      assert_true status.success?, "stdout: #{out}\nstderr: #{err}"
      assert_include out, "1 tests, 1 assertions, 0 failures, 0 errors"
    end
  end

  def test_name_filter_matching_nothing_fails
    out, _err, status = run_cli(File.join(FIXTURES, "passing"), "-n", "no_such_test")
    assert_equal 1, status.exitstatus
    assert_include out, "No tests were run (filter: no_such_test)"
  end

  def test_exit_status_of_the_tests_is_propagated
    Dir.mktmpdir do |root|
      dir = write_test_project(root, "exit 3")
      _out, _err, status = run_cli(dir)
      assert_equal 3, status.exitstatus
    end
  end

  def test_new_assertion_messages
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "ReportTest")
    assert_include out, "9 tests, 16 assertions, 8 failures, 0 errors"
    assert_include out, "Expected /a/ to match nil\n"
    assert_include out, "Expected /b+z/ to match \"abc\"\n"
    assert_include out, "Expected \"xyz\" to match \"abc\"\n"
    assert_include out, "Expected 1 not to equal 1\n"
    assert_include out, "Expected a value other than nil\n"
    assert_include out, "[1, 2] includes 2\n"
    assert_include out, "Failed refutation, no message given.\n"
    assert_include out, "Failure: ReportTest#test_refute_message_fail\nshould differ\n"
  end
end
