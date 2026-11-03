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

        msg = "Expected: #{expected.inspect}\n  Actual: #{actual.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_not_equal(expected, actual, message = nil)
        @assertions += 1
        return true unless expected == actual

        msg = "Expected #{actual.inspect} not to equal #{expected.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_match(pattern, string, message = nil)
        @assertions += 1
        return true if pattern_matches?(pattern, string)

        msg = "Expected #{pattern.inspect} to match #{string.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_nil(value, message = nil)
        @assertions += 1
        return true if value.nil?

        msg = "Expected nil, got #{value.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_not_nil(value, message = nil)
        @assertions += 1
        return true unless value.nil?

        msg = "Expected a value other than nil"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_include(collection, item, message = nil)
        @assertions += 1
        return true if collection.include?(item)

        msg = "#{collection.inspect} does not include #{item.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_includes(collection, item, message = nil)
        assert_include(collection, item, message)
      end

      def assert_not_include(collection, item, message = nil)
        @assertions += 1
        return true unless collection.include?(item)

        msg = "#{collection.inspect} includes #{item.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_raise(klass)
        @assertions += 1
        begin
          yield
        rescue AssertionFailedError => e
          # a failed assertion inside the block is not "the expected error"
          raise e
        rescue StandardError => e
          return e if e.is_a?(klass)

          raise AssertionFailedError, "Expected #{klass} but got #{e.class}"
        end
        raise AssertionFailedError, "Expected #{klass} but nothing was raised"
      end

      private

      def pattern_matches?(pattern, string)
        return false unless string.is_a?(String)
        return pattern.match?(string) if pattern.is_a?(Regexp)

        string.include?(pattern)
      end
    end
  end
end
