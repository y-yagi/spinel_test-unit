# frozen_string_literal: true

module SpinelTest
  module Unit
    class AssertionFailedError < StandardError
    end

    class TestCase
      def initialize
        @assertions = 0
      end

      def assertions
        @assertions
      end

      def setup
      end

      def teardown
      end

      def assert(test, message = nil)
        @assertions += 1
        return true if test

        raise AssertionFailedError, (message || "Failed assertion, no message given.")
      end

      def refute(test, message = nil)
        @assertions += 1
        return true unless test

        raise AssertionFailedError, (message || "Failed refutation, no message given.")
      end

      def assert_equal(expected, actual, message = nil)
        @assertions += 1
        return true if expected == actual

        failure("Expected: #{expected.inspect}\n  Actual: #{actual.inspect}" + diff_section(expected, actual), message)
      end

      def assert_not_equal(expected, actual, message = nil)
        @assertions += 1
        return true unless expected == actual

        failure("Expected #{actual.inspect} not to equal #{expected.inspect}", message)
      end

      def assert_match(pattern, string, message = nil)
        @assertions += 1
        return true if pattern_matches?(pattern, string)

        failure("Expected #{pattern.inspect} to match #{string.inspect}", message)
      end

      def assert_nil(value, message = nil)
        @assertions += 1
        return true if value.nil?

        failure("Expected nil, got #{value.inspect}", message)
      end

      def assert_not_nil(value, message = nil)
        @assertions += 1
        return true unless value.nil?

        failure("Expected a value other than nil", message)
      end

      def assert_include(collection, item, message = nil)
        @assertions += 1
        return true if collection.include?(item)

        failure("#{collection.inspect} does not include #{item.inspect}", message)
      end

      def assert_includes(collection, item, message = nil)
        assert_include(collection, item, message)
      end

      def assert_not_include(collection, item, message = nil)
        @assertions += 1
        return true unless collection.include?(item)

        failure("#{collection.inspect} includes #{item.inspect}", message)
      end

      def assert_raise(klass, match: nil)
        @assertions += 1
        begin
          yield
        rescue AssertionFailedError => e
          # a failed assertion inside the block is not "the expected error"
          raise e
        rescue StandardError => e
          return expected_exception(e, klass, match, e.instance_of?(klass))
        end
        raise AssertionFailedError, "Expected #{klass} but nothing was raised"
      end

      def assert_raise_kind_of(klass, match: nil)
        @assertions += 1
        begin
          yield
        rescue AssertionFailedError => e
          raise e
        rescue StandardError => e
          return expected_exception(e, klass, match, e.is_a?(klass))
        end
        raise AssertionFailedError, "Expected #{klass} but nothing was raised"
      end

      private

      def failure(text, message)
        raise AssertionFailedError, message ? message + "\n" + text : text
      end

      def expected_exception(e, klass, match, class_matches)
        raise AssertionFailedError, "Expected #{klass} but got #{e.class}" unless class_matches
        return e if match.nil? || pattern_matches?(match, e.message)

        raise AssertionFailedError, "Expected #{klass} with a message matching #{match.inspect} but got #{e.message.inspect}"
      end

      def diff_section(expected, actual)
        return "" unless multiline_strings?(expected, actual)

        "\nDiff:\n" + Diff.lines(expected, actual)
      rescue ArgumentError, EncodingError
        ""
      end

      def multiline_strings?(expected, actual)
        expected.is_a?(String) && actual.is_a?(String) && expected.include?("\n") && actual.include?("\n")
      end

      def pattern_matches?(pattern, string)
        return false unless string.is_a?(String)
        return pattern.match?(string) if pattern.is_a?(Regexp)

        string.include?(pattern)
      end
    end
  end
end
