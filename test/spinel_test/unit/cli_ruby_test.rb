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

  def test_multiline_diff_report
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "test_multiline_diff")
    assert_include out, "Diff:\n  alpha\n  beta\n- gamma\n+ GAMMA\n  delta\n  epsilon\n  ...\n"
  end

  def test_single_line_report_has_no_diff
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "test_single_line")
    assert_include out, "Failure: ReportTest#test_single_line_has_no_diff\nExpected: \"one\"\n  Actual: \"two\"\n    at "
    assert_not_include out, "Diff:"
  end

  def test_new_assertion_messages
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "ReportTest")
    assert_include out, "12 tests, 18 assertions, 10 failures, 1 errors"
    assert_include out, "Expected /a/ to match nil\n"
    assert_include out, "Expected /b+z/ to match \"abc\"\n"
    assert_include out, "Expected \"xyz\" to match \"abc\"\n"
    assert_include out, "Expected 1 not to equal 1\n"
    assert_include out, "Expected a value other than nil\n"
    assert_include out, "[1, 2] includes 2\n"
    assert_include out, "Failed refutation, no message given.\n"
    assert_include out, "Failure: ReportTest#test_refute_message_fail\nshould differ\n"
  end

  def test_failure_report_shows_the_failing_lines
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "test_match_fail")
    assert_include out, "Failure: ReportTest#test_match_fail\nExpected /b+z/ to match \"abc\"\n    at test/fixtures/reporting/report_test.rb:13\n"
  end

  def test_error_report_shows_frames_outside_the_framework
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "test_error_in_helper")
    expected = "Error: ReportTest#test_error_in_helper\ndeep\n" \
               "    at test/fixtures/reporting/report_test.rb:42\n" \
               "    at test/fixtures/reporting/report_test.rb:46\n"
    assert_include out, expected
    assert_not_include out, "main.rb"
    assert_not_include out, "lib/spinel_test"
  end

  def test_repeated_locations_from_block_builtins_are_shown_once
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "FramesTest")
    expected = "Error: FramesTest#test_error_in_block\nin block\n" \
               "    at test/fixtures/reporting/frames_test.rb:5\n" \
               "    at test/fixtures/reporting/frames_test.rb:9\n\n"
    assert_include out, expected
  end

  def test_error_raised_only_in_teardown_shows_where
    out, _err, _status = run_cli(File.join(FIXTURES, "reporting"), "-n", "TeardownErrorTest")
    assert_include out, "Error: TeardownErrorTest#test_body_passes\nteardown boom\n    at test/fixtures/reporting/frames_test.rb:15\n"
  end

  def test_locations_are_relative_to_the_root_not_the_working_directory
    Dir.mktmpdir do |root|
      write(root, "test/a_test.rb", <<~RUBY)
        require "spinel_test/unit"
        class ATest < SpinelTest::Unit::TestCase
          def test_a
            assert_equal 1, 2
          end
        end
      RUBY
      out, = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../../../lib", __dir__), "-e",
                            "require 'spinel_test/unit/cli'; exit SpinelTest::Unit::CLI.start(['--ruby'], root: ARGV[0])", root,
                            chdir: "/")
      assert_include out, "    at test/a_test.rb:4\n"
    end
  end
end
