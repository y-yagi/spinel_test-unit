require "test_helper"

class UsesLibTest < LibBase
  def test_helper_from_library
    assert_equal 42, helper_value
  end
end
