# frozen_string_literal: true

module SpinelTest
  module Unit
    class Runner
      def initialize(filter = "")
        @filter = filter
        @tests = 0
        @assertions = 0
        @failures = 0
        @errors = 0
        @details = []
      end

      def selected?(name)
        @filter == "" || name.include?(@filter)
      end

      # Runs one test: setup, the block (which calls the test method), teardown.
      def run(name, tc)
        return unless selected?(name)

        @tests += 1
        status = 0
        message = ""
        begin
          tc.setup
          yield
        rescue AssertionFailedError => e
          status = 1
          message = e.message
        rescue Exception => e
          raise e if fatal?(e)

          status = 2
          message = e.message
        end
        begin
          tc.teardown
        rescue Exception => e
          raise e if fatal?(e)

          if status == 0
            status = 2
            message = e.message
          else
            message = message + "\nTeardown also raised: " + e.message
          end
        end
        @assertions += tc.assertions
        if status == 0
          print "."
        elsif status == 1
          print "F"
          @failures += 1
          @details.push("Failure: #{name}\n#{message}")
        else
          print "E"
          @errors += 1
          @details.push("Error: #{name}\n#{message}")
        end
      end

      # Exceptions that must end the process instead of being reported as a test error.
      def fatal?(e)
        e.is_a?(SystemExit) || e.is_a?(Interrupt)
      end

      def passed?
        @failures == 0 && @errors == 0
      end

      def summary
        "#{@tests} tests, #{@assertions} assertions, #{@failures} failures, #{@errors} errors"
      end

      # Prints the report and returns the process exit status.
      def finish
        puts ""
        @details.each do |d|
          puts ""
          puts d
        end
        puts ""
        puts summary
        if @tests == 0
          puts "No tests were run#{@filter == "" ? "" : " (filter: " + @filter + ")"}"
          return 1
        end
        passed? ? 0 : 1
      end
    end
  end
end
