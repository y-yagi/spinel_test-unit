require "spinel_test/unit"

class BrokenTest < SpinelTest::Unit::TestCase
  def test_ok
    assert true
  end

  def test_failure
    assert 1 + 1 == 3, "math is broken"
  end

  def test_error
    raise "boom"
  end
end
