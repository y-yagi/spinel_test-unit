# frozen_string_literal: true

require "test_helper"

class GeneratorTest < Test::Unit::TestCase
  def test_generates_literal_calls
    klass = SpinelTest::Unit::Scanner::TestClass.new(name: "FooTest", methods: ["test_a", "test_b"])
    code = SpinelTest::Unit::Generator.generate([{ require: "test/foo_test", classes: [klass] }])

    assert_include code, %(require "spinel_test/unit"\n)
    assert_include code, %(require "test/foo_test"\n)
    assert_include code, %(runner.run("FooTest#test_a", t) { t.test_a }\n)
    assert_include code, %(runner.run("FooTest#test_b", t) { t.test_b }\n)
    assert_include code, "t = FooTest.new\n"
    assert_match(/exit runner\.finish\n\z/, code)
  end

  def test_generated_code_is_valid_ruby
    klass = SpinelTest::Unit::Scanner::TestClass.new(name: "A::BTest", methods: ["test_x"])
    code = SpinelTest::Unit::Generator.generate([{ require: "a", classes: [klass] }])
    assert Prism.parse(code).success?
  end
end
