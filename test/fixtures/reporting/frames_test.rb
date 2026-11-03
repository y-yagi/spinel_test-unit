require "spinel_test/unit"

class FramesTest < SpinelTest::Unit::TestCase
  def each_item
    [1].each { |n| raise ArgumentError, "in block" }
  end

  def test_error_in_block
    each_item
  end
end

class TeardownErrorTest < SpinelTest::Unit::TestCase
  def teardown
    raise "teardown boom"
  end

  def test_body_passes
    assert true
  end
end
