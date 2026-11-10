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
    assert_include "hello", "ell"
  end

  def test_raise
    e = assert_raise(ArgumentError) { raise ArgumentError, "bad" }
    assert_equal "bad", e.message
    e = assert_raise_kind_of(StandardError) { raise ArgumentError, "subclass" }
    assert_equal "subclass", e.message
    assert_raise_kind_of(ArgumentError, match: "ad") { raise ArgumentError, "bad" }
    assert_raise(ArgumentError, match: "ad") { raise ArgumentError, "bad" }
    assert_raise(ArgumentError, match: /ba/) { raise ArgumentError, "bad" }
  end
end
