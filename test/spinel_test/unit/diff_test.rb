# frozen_string_literal: true

require "test_helper"

class DiffTest < Test::Unit::TestCase
  def diff(expected, actual, context = 2)
    SpinelTest::Unit::Diff.lines(expected, actual, context)
  end

  def test_marks_changed_line
    assert_equal "  a\n- b\n+ B\n  c", diff("a\nb\nc", "a\nB\nc")
  end

  def test_marks_inserted_line
    assert_equal "  a\n+ new\n  b", diff("a\nb", "a\nnew\nb")
  end

  def test_marks_deleted_line
    assert_equal "  a\n- gone\n  b", diff("a\ngone\nb", "a\nb")
  end

  def test_collapses_unchanged_lines_beyond_context
    expected = (1..10).map(&:to_s).join("\n")
    actual = expected.sub("5", "five")
    assert_equal "  ...\n  3\n  4\n- 5\n+ five\n  6\n  7\n  ...", diff(expected, actual)
  end

  def test_context_size_is_configurable
    expected = (1..5).map(&:to_s).join("\n")
    actual = expected.sub("3", "three")
    assert_equal "  1\n  2\n- 3\n+ three\n  4\n  5", diff(expected, actual, 1)
  end

  def test_keeps_both_changes_in_one_hunk_when_close
    assert_equal "- a\n+ A\n  x\n- b\n+ B", diff("a\nx\nb", "A\nx\nB")
  end

  def test_trailing_newline_difference_is_shown
    assert_equal "  a\n  b\n- \"\"", diff("a\nb\n", "a\nb")
  end

  def test_uses_the_longest_common_subsequence
    assert_equal "- x\n  a\n  b\n+ y", diff("x\na\nb", "a\nb\ny")
  end

  def test_common_start_and_end_lines_are_not_part_of_the_table
    expected = (1..5000).map { |n| "line #{n}" }.join("\n")
    actual = expected.sub("line 2500\n", "changed\n")
    assert_equal "  ...\n  line 2498\n  line 2499\n- line 2500\n+ changed\n  line 2501\n  line 2502\n  ...", diff(expected, actual)
  end

  def test_context_survives_trimming_at_the_edges
    assert_equal "- a\n+ A\n  b\n  c\n  ...", diff("a\nb\nc\nd\ne", "A\nb\nc\nd\ne")
    assert_equal "  ...\n  c\n  d\n- e\n+ E", diff("a\nb\nc\nd\ne", "a\nb\nc\nd\nE")
  end

  def test_skips_the_diff_when_the_differing_lines_are_too_many
    expected = (1..1200).map { |n| "e#{n}" }.join("\n")
    actual = (1..1200).map { |n| "a#{n}" }.join("\n")
    assert_equal "  (diff skipped: 1200 expected and 1200 actual lines differ)", diff(expected, actual)
  end

  def test_common_lines_do_not_count_toward_the_size_cap
    shared = (1..3000).map { |n| "s#{n}" }
    expected = (shared + ["x"] + shared).join("\n")
    actual = (shared + ["y"] + shared).join("\n")
    assert_equal "  ...\n  s2999\n  s3000\n- x\n+ y\n  s1\n  s2\n  ...", diff(expected, actual)
  end

  def test_lines_with_carriage_returns_are_inspected
    assert_equal "- \"a\\r\"\n+ a\n  b", diff("a\r\nb", "a\nb")
  end

  def test_lines_with_control_characters_are_inspected
    assert_equal "- \"\\e[31mred\"\n+ red\n  b", diff("\e[31mred\nb", "red\nb")
    assert_equal "- \"a\\u0000\"\n+ a\n  b", diff("a\0\nb", "a\nb")
  end

  def test_tabs_inside_a_line_are_shown_as_is
    assert_equal "- a\tb\n+ a b\n  c", diff("a\tb\nc", "a b\nc")
  end

  def test_empty_lines_are_inspected
    assert_equal "  a\n- \"\"\n  b\n  \"\"", diff("a\n\nb\n", "a\nb\n")
  end

  def test_diffs_exactly_the_maximum_number_of_table_cells
    expected = (1..1000).map { |n| "e#{n}" }.join("\n")
    actual = (1..1000).map { |n| "a#{n}" }.join("\n")
    result = diff(expected, actual, 0)
    assert_not_include result, "skipped"
    assert_equal 2000, result.split("\n").length
  end

  def test_skips_the_diff_one_cell_beyond_the_maximum
    expected = (1..1000).map { |n| "e#{n}" }.join("\n")
    actual = (1..1001).map { |n| "a#{n}" }.join("\n")
    assert_equal "  (diff skipped: 1000 expected and 1001 actual lines differ)", diff(expected, actual)
  end

  def test_context_zero_shows_only_changes
    assert_equal "  ...\n- c\n+ X\n  ...", diff("a\nb\nc\nd\ne", "a\nb\nX\nd\ne", 0)
  end

  def test_a_literal_ellipsis_line_is_inspected
    assert_equal "  a\n- \"...\"\n+ b", diff("a\n...", "a\nb")
  end

  def test_empty_and_quoted_lines_are_told_apart
    assert_equal "  a\n- \"\"\n+ \"\\\"\\\"\"", diff("a\n", "a\n\"\"")
  end

  def test_lines_with_edge_whitespace_are_inspected
    assert_equal "  a\n- \"b \"\n+ \"\\tb\"", diff("a\nb ", "a\n\tb")
  end

  def test_a_single_hidden_line_is_not_collapsed
    assert_equal "  1\n  2\n- 3\n+ three\n  4\n  5", diff("1\n2\n3\n4\n5", "1\n2\nthree\n4\n5", 1)
  end

  def test_two_hidden_lines_are_collapsed
    assert_equal "  ...\n  2\n- 3\n+ three\n  4\n  ...", diff("0\n1\n2\n3\n4\n5\n6", "0\n1\n2\nthree\n4\n5\n6", 1)
  end
end
