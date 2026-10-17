require "spinel_test/unit"

class CalcTest < SpinelTest::Unit::TestCase
  def setup
    @n = 2
  end

  def test_add
    assert @n + 1 == 3
  end

  def test_truthy
    assert true, "never shown"
    assert 1
  end
end
