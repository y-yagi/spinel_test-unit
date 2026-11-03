# frozen_string_literal: true

module SpinelTest
  module Unit
    class Runner
      MAX_FRAMES = 3
      FRAMEWORK_DIR = File.dirname(File.expand_path(__FILE__)) + "/"

      def initialize(filter = "", root = "")
        @filter = filter
        @root = root
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
      # location is the "file:line" of the test method, shown when the exception
      # has no backtrace of its own.
      def run(name, tc, location = "")
        return unless selected?(name)

        @tests += 1
        status = 0
        message = ""
        frames = []
        teardown_message = ""
        begin
          tc.setup
          yield
        rescue AssertionFailedError => e
          status = 1
          message = e.message
          frames = report_frames(e, location)
        rescue Exception => e
          raise e if fatal?(e)

          status = 2
          message = e.message
          frames = report_frames(e, location)
        end
        begin
          tc.teardown
        rescue Exception => e
          raise e if fatal?(e)

          if status == 0
            status = 2
            message = e.message
            frames = report_frames(e, location)
          else
            teardown_message = "\nTeardown also raised: " + e.message
          end
        end
        @assertions += tc.assertions
        if status == 0
          print "."
        elsif status == 1
          print "F"
          @failures += 1
          @details.push("Failure: #{name}\n#{message}#{where(frames)}#{teardown_message}")
        else
          print "E"
          @errors += 1
          @details.push("Error: #{name}\n#{message}#{where(frames)}#{teardown_message}")
        end
      end

      def report_frames(e, location)
        backtrace = e.backtrace || []
        frames = []
        backtrace.each do |frame|
          next if framework_frame?(frame)
          next unless frames.empty? || under_root?(frame)

          shown = relative_path(frame_location(frame))
          next if frames.length > 0 && frames[frames.length - 1] == shown

          frames.push(shown)
          break if frames.length >= MAX_FRAMES
        end
        frames.push(location) if frames.empty? && location != ""
        frames
      end

      def under_root?(frame)
        @root == "" || frame.start_with?(@root + "/")
      end

      def framework_frame?(frame)
        frame.start_with?(FRAMEWORK_DIR) || frame.start_with?($0 + ":")
      end

      def frame_location(frame)
        index = frame.index(":in ")
        index ? frame[0, index] : frame
      end

      def relative_path(location)
        return location if @root == ""

        prefix = @root + "/"
        location.start_with?(prefix) ? location[prefix.length, location.length] : location
      end

      def where(frames)
        text = ""
        frames.each { |frame| text += "\n    at " + frame }
        text
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
