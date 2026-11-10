require "spinel_test/unit"

class FooTest < SpinelTest::Unit::TestCase
  def test_a
    assert true
  end

  def test_b
    assert true
  end
end

class MyFooTest < SpinelTest::Unit::TestCase
  def test_a
    assert true
  end
end

class BarTest < SpinelTest::Unit::TestCase
  def test_a
    assert true
  end
end
