require "spinel_test/unit"

class ReportTest < SpinelTest::Unit::TestCase
  def test_multiline_diff
    assert_equal "alpha\nbeta\ngamma\ndelta\nepsilon\nzeta\neta\ntheta", "alpha\nbeta\nGAMMA\ndelta\nepsilon\nzeta\neta\ntheta"
  end

  def test_single_line_has_no_diff
    assert_equal "one", "two"
  end

  def test_match_fail
    assert_match(/b+z/, "abc")
  end

  def test_match_string_fail
    assert_match("xyz", "abc")
  end

  def test_not_equal_fail
    assert_not_equal 1, 1
  end

  def test_not_nil_fail
    n = nil
    assert_not_nil n
  end

  def test_not_includes_fail
    assert_not_include [1, 2], 2
  end

  def test_refute_fail
    refute true
  end

  def test_refute_message_fail
    refute 1 == 1, "should differ"
  end

  def test_new_assertions_pass
    assert_match(/b+/, "abbc")
    assert_match("bc", "abc")
    assert_not_equal 1, 2
    assert_not_include [1], 2
    refute false
    refute nil
    assert_not_include({ 1 => 2 }, 2)
    assert_not_include "hello", "xyz"
  end

  def test_match_nil_subject_fail
    subject = nil
    assert_match(/a/, subject)
  end
end
