require "spinel_test/unit"

class AssertionsTest < SpinelTest::Unit::TestCase
  def test_equal
    assert_equal 3, 1 + 2
    assert_equal "a", "a"
    assert_equal [1, 2], [1, 2]
    assert_equal 1, 1.0
  end

  def test_nil
    assert_nil nil
  end

  def test_includes
    assert_includes [1, 2, 3], 2
    assert_includes "hello", "ell"
  end

  def test_raise
    e = assert_raise(ArgumentError) { raise ArgumentError, "bad" }
    assert_equal "bad", e.message
    assert_raise(StandardError) { raise ArgumentError, "subclass" }
  end
end
