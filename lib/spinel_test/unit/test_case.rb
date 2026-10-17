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

      def assert_equal(expected, actual, message = nil)
        @assertions += 1
        return true if expected == actual

        msg = "Expected: #{expected.inspect}\n  Actual: #{actual.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_nil(v, message = nil)
        @assertions += 1
        return true if v.nil?

        msg = "Expected nil, got #{v.inspect}"
        msg = message + "\n" + msg if message
        raise AssertionFailedError, msg
      end

      def assert_includes(coll, item, message = nil)
        @assertions += 1
        return true if coll.include?(item)

        msg = "#{coll.inspect} does not include #{item.inspect}"
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
    end
  end
end
