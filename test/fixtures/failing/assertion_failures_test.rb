require "spinel_test/unit"

class AssertionFailuresTest < SpinelTest::Unit::TestCase
  def test_equal_ints
    assert_equal 1, 2
  end

  def test_equal_with_message
    assert_equal 1, 2, "custom equal"
  end

  def test_equal_int_nil
    n = nil
    assert_equal 1, n
  end

  def test_equal_string_int
    assert_equal "1", 1
  end

  def test_equal_float
    assert_equal 1, 1.5
  end

  def test_nil_fail
    assert_nil 42
  end

  def test_nil_with_message
    assert_nil "x", "custom nil"
  end

  def test_includes_fail
    assert_includes [1, 2], 3
  end

  def test_raise_wrong_class
    assert_raise(ArgumentError) { raise TypeError, "t" }
  end

  def test_raise_nothing
    assert_raise(ArgumentError) { 1 + 1 }
  end
end
