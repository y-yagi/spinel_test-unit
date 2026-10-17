# frozen_string_literal: true

require "test_helper"

class ScannerTest < Test::Unit::TestCase
  def scan(src)
    SpinelTest::Unit::Scanner.scan([src])
  end

  def test_extracts_classes_and_test_methods
    classes = scan(<<~RUBY)
      class FooTest < SpinelTest::Unit::TestCase
        def setup; end
        def test_a; end
        def test_b; end
        def helper; end
      end
      class NotATest
        def test_x; end
      end
    RUBY
    assert_equal ["FooTest"], classes.map(&:name)
    assert_equal ["test_a", "test_b"], classes.first.methods
  end

  def test_nested_namespace
    classes = scan(<<~RUBY)
      module App
        class BarTest < SpinelTest::Unit::TestCase
          def test_a; end
        end
      end
    RUBY
    assert_equal ["App::BarTest"], classes.map(&:name)
  end

  def test_inherits_tests_through_intermediate_class
    classes = scan(<<~RUBY)
      class BaseTest < SpinelTest::Unit::TestCase
        def test_base; end
      end
      class ChildTest < BaseTest
        def test_child; end
      end
    RUBY
    child = classes.find { |c| c.name == "ChildTest" }
    assert_equal ["test_base", "test_child"], child.methods
  end

  def test_class_without_tests_is_skipped
    assert_equal [], scan("class EmptyTest < SpinelTest::Unit::TestCase\nend\n")
  end

  def test_excludes_methods_after_bare_private
    classes = scan(<<~RUBY)
      class FooTest < SpinelTest::Unit::TestCase
        def test_a; end
        protected
        def test_b; end
        private
        def test_c; end
        public
        def test_d; end
      end
    RUBY
    assert_equal ["test_a", "test_d"], classes.first.methods
  end

  def test_excludes_private_def_and_private_symbol
    classes = scan(<<~RUBY)
      class FooTest < SpinelTest::Unit::TestCase
        def test_a; end
        private def test_b; end
        def test_c; end
        def test_d; end
        private :test_c
        private
        public
        def test_e; end
      end
    RUBY
    assert_equal ["test_a", "test_d", "test_e"], classes.first.methods
  end

  def test_scan_files_resolves_parent_in_other_file
    sources = {
      "base_helper.rb" => "class BaseHelper < SpinelTest::Unit::TestCase\n  def test_inherited; end\nend\n",
      "c_test.rb" => "class CTest < BaseHelper\n  def test_own; end\nend\n"
    }
    result = SpinelTest::Unit::Scanner.scan_files(sources, ["c_test.rb"])
    assert_equal ["CTest"], result.classes.map(&:name)
    assert_equal ["test_inherited", "test_own"], result.classes.first.methods
    assert_equal ["base_helper.rb", "c_test.rb"], result.classes.first.files
    assert_equal [], result.warnings
  end

  def test_scan_files_warns_on_unresolved_parent
    sources = { "x_test.rb" => "class XTest < Mystery\n  def test_a; end\nend\n" }
    result = SpinelTest::Unit::Scanner.scan_files(sources, ["x_test.rb"])
    assert_equal [], result.classes
    assert_equal [["x_test.rb", "XTest", "Mystery"]], result.warnings
  end

  def test_superclass_qualified_regardless_of_file_order
    base = "module M\n  class Base < SpinelTest::Unit::TestCase\n    def test_base; end\n  end\nend\n"
    child = "module M\n  class T < Base\n    def test_t; end\n  end\nend\n"
    [{ "child.rb" => child, "base.rb" => base }, { "base.rb" => base, "child.rb" => child }].each do |sources|
      result = SpinelTest::Unit::Scanner.scan_files(sources, ["child.rb"])
      assert_equal ["M::T"], result.classes.map(&:name)
      assert_equal ["test_base", "test_t"], result.classes.first.methods
      assert_equal [], result.warnings
    end
  end

  def test_superclass_defined_later_in_same_file
    classes = scan(<<~RUBY)
      module M
        class T < Base
          def test_t; end
        end
        class Base < SpinelTest::Unit::TestCase
          def test_base; end
        end
      end
    RUBY
    t = classes.find { |c| c.name == "M::T" }
    assert_equal ["test_base", "test_t"], t.methods
  end

  def test_target_when_any_file_is_a_target
    sources = {
      "early.rb" => "class FooTest < SpinelTest::Unit::TestCase\n  def test_early; end\nend\n",
      "foo_test.rb" => "class FooTest\n  def test_late; end\nend\n"
    }
    result = SpinelTest::Unit::Scanner.scan_files(sources, ["foo_test.rb"])
    assert_equal ["FooTest"], result.classes.map(&:name)
    assert_equal ["test_early", "test_late"], result.classes.first.methods
    assert_equal "foo_test.rb", result.classes.first.file
    assert_equal ["early.rb", "foo_test.rb"], result.classes.first.files
  end

  def test_requires_collects_string_literal_requires
    src = <<~RUBY
      require "a/b"
      require_relative "c"
      require name
      begin
        require "d"
      rescue LoadError
      end
      foo.require "e"
    RUBY
    assert_equal [[:require, "a/b"], [:relative, "c"], [:require, "d"]], SpinelTest::Unit::Scanner.requires(src)
  end

  def test_requires_returns_empty_for_unparseable_source
    assert_equal [], SpinelTest::Unit::Scanner.requires("require(")
  end
end
