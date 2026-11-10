# frozen_string_literal: true

require "test_helper"

class RunnerTest < Test::Unit::TestCase
  def runner(filter: "", testcase: "")
    SpinelTest::Unit::Runner.new(filter, "", testcase)
  end

  def test_no_filter_selects_everything
    assert_true runner.selected?("FooTest#test_a")
  end

  def test_name_filter_is_a_substring
    assert_true runner(filter: "FooTest#").selected?("FooTest#test_a")
    assert_true runner(filter: "FooTest#").selected?("MyFooTest#test_a")
    assert_false runner(filter: "FooTest#").selected?("BarTest#test_a")
  end

  def test_name_filter_as_regexp
    assert_true runner(filter: "/\\AFooTest#test_[ab]\\z/").selected?("FooTest#test_b")
    assert_false runner(filter: "/\\AFooTest#/").selected?("MyFooTest#test_a")
  end

  def test_testcase_is_an_exact_class_name
    assert_true runner(testcase: "FooTest").selected?("FooTest#test_a")
    assert_false runner(testcase: "FooTest").selected?("MyFooTest#test_a")
    assert_false runner(testcase: "FooTest").selected?("A::FooTest#test_a")
    assert_true runner(testcase: "A::FooTest").selected?("A::FooTest#test_a")
  end

  def test_testcase_as_regexp
    assert_true runner(testcase: "/Foo/").selected?("MyFooTest#test_a")
    assert_false runner(testcase: "/\\AFoo/").selected?("MyFooTest#test_a")
  end

  def test_testcase_and_name_filter_both_apply
    r = runner(filter: "test_b", testcase: "FooTest")
    assert_true r.selected?("FooTest#test_b")
    assert_false r.selected?("FooTest#test_a")
  end

  def test_a_lone_slash_is_a_substring
    assert_true runner(filter: "/").selected?("A/B#test")
  end
end
