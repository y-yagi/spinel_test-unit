# frozen_string_literal: true

module SpinelTest
  module Unit
    class Diff
      MAX_TABLE_CELLS = 1_000_000

      def self.lines(expected, actual, context = 2)
        new(expected.split("\n", -1), actual.split("\n", -1), context).render
      end

      def initialize(expected_lines, actual_lines, context)
        @expected_lines = expected_lines
        @actual_lines = actual_lines
        @context = context
        @prefix = common_prefix_length
        @suffix = common_suffix_length
        @expected_middle = middle(expected_lines)
        @actual_middle = middle(actual_lines)
      end

      def render
        if @expected_middle.length * @actual_middle.length > MAX_TABLE_CELLS
          return "  (diff skipped: #{@expected_middle.length} expected and #{@actual_middle.length} actual lines differ)"
        end

        entries = unchanged(@expected_lines[0, @prefix]) + edits + unchanged(@expected_lines[@expected_lines.length - @suffix, @suffix])
        collapse(entries)
      end

      private

      def common_prefix_length
        limit = @expected_lines.length < @actual_lines.length ? @expected_lines.length : @actual_lines.length
        count = 0
        count += 1 while count < limit && @expected_lines[count] == @actual_lines[count]
        count
      end

      def common_suffix_length
        limit = (@expected_lines.length < @actual_lines.length ? @expected_lines.length : @actual_lines.length) - @prefix
        count = 0
        while count < limit && @expected_lines[@expected_lines.length - 1 - count] == @actual_lines[@actual_lines.length - 1 - count]
          count += 1
        end
        count
      end

      def middle(lines)
        lines[@prefix, lines.length - @prefix - @suffix]
      end

      def unchanged(lines)
        lines.map { |line| "  " + display(line) }
      end

      def display(line)
        ambiguous?(line) ? line.inspect : line
      end

      def ambiguous?(line)
        line == "" || line == "..." || line.include?("\r") || line.start_with?("\"") ||
          line.start_with?(" ", "\t") || line.end_with?(" ", "\t")
      end

      def edits
        lengths = lcs_lengths
        entries = []
        expected_index = 0
        actual_index = 0
        while expected_index < @expected_middle.length && actual_index < @actual_middle.length
          if @expected_middle[expected_index] == @actual_middle[actual_index]
            entries.push("  " + display(@expected_middle[expected_index]))
            expected_index += 1
            actual_index += 1
          elsif lengths[expected_index + 1][actual_index] >= lengths[expected_index][actual_index + 1]
            entries.push("- " + display(@expected_middle[expected_index]))
            expected_index += 1
          else
            entries.push("+ " + display(@actual_middle[actual_index]))
            actual_index += 1
          end
        end
        push_rest(entries, "- ", @expected_middle, expected_index)
        push_rest(entries, "+ ", @actual_middle, actual_index)
        entries
      end

      def push_rest(entries, marker, lines, from)
        index = from
        while index < lines.length
          entries.push(marker + display(lines[index]))
          index += 1
        end
      end

      def lcs_lengths
        lengths = Array.new(@expected_middle.length + 1) { Array.new(@actual_middle.length + 1, 0) }
        expected_index = @expected_middle.length - 1
        while expected_index >= 0
          actual_index = @actual_middle.length - 1
          while actual_index >= 0
            if @expected_middle[expected_index] == @actual_middle[actual_index]
              lengths[expected_index][actual_index] = lengths[expected_index + 1][actual_index + 1] + 1
            else
              down = lengths[expected_index + 1][actual_index]
              right = lengths[expected_index][actual_index + 1]
              lengths[expected_index][actual_index] = down >= right ? down : right
            end
            actual_index -= 1
          end
          expected_index -= 1
        end
        lengths
      end

      def collapse(entries)
        visible = visible_entries(entries)
        out = []
        index = 0
        while index < entries.length
          run_end = hidden_run_end(visible, index)
          if run_end - index >= 2
            out.push("  ...")
            index = run_end
          else
            out.push(entries[index])
            index += 1
          end
        end
        out.join("\n")
      end

      def hidden_run_end(visible, from)
        index = from
        index += 1 while index < visible.length && !visible[index]
        index
      end

      def visible_entries(entries)
        visible = Array.new(entries.length, false)
        entries.each_with_index do |entry, index|
          next if entry.start_with?("  ")

          first = index - @context
          first = 0 if first < 0
          last = index + @context
          last = entries.length - 1 if last >= entries.length
          first.upto(last) { |position| visible[position] = true }
        end
        visible
      end
    end
  end
end
