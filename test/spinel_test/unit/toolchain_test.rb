# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ToolchainTest < Test::Unit::TestCase
  def setup
    @env = ENV.to_h
  end

  def teardown
    ENV.replace(@env)
  end

  def fake_exe(dir, name, body = "#!/bin/sh\n")
    path = File.join(dir, name)
    File.write(path, body)
    File.chmod(0o755, path)
    path
  end

  def test_spinel_env_wins
    Dir.mktmpdir do |dir|
      fake_exe(dir, "spinel")
      ENV["PATH"] = dir
      ENV["SPINEL"] = "/custom/spinel"
      assert_equal "/custom/spinel", SpinelTest::Unit::Toolchain.spinel
    end
  end

  def test_path_is_next
    Dir.mktmpdir do |dir|
      exe = fake_exe(dir, "spinel")
      ENV["PATH"] = dir
      ENV.delete("SPINEL")
      assert_equal exe, SpinelTest::Unit::Toolchain.spinel
    end
  end

  def test_mise_which_is_last
    Dir.mktmpdir do |dir|
      fake_exe(dir, "mise", "#!/bin/sh\necho /mise/spinel\n")
      ENV["PATH"] = dir
      ENV.delete("SPINEL")
      assert_equal "/mise/spinel", SpinelTest::Unit::Toolchain.spinel
    end
  end

  def test_compile_flags_default_to_o0_split_across_cpus
    ENV.delete("SPINEL_TEST_UNIT_OPT")
    ENV.delete("SPINEL_TEST_UNIT_JOBS")
    jobs = Etc.nprocessors.clamp(1, 16)
    assert_equal ["-O", "0", "--jobs=#{jobs}"], SpinelTest::Unit::Toolchain.compile_flags
  end

  def test_compile_flags_from_env
    ENV["SPINEL_TEST_UNIT_OPT"] = "2"
    ENV["SPINEL_TEST_UNIT_JOBS"] = "1"
    assert_equal ["-O", "2", "--jobs=1"], SpinelTest::Unit::Toolchain.compile_flags
  end

  def test_compile_flags_ignore_empty_env
    ENV["SPINEL_TEST_UNIT_OPT"] = ""
    ENV["SPINEL_TEST_UNIT_JOBS"] = ""
    jobs = Etc.nprocessors.clamp(1, 16)
    assert_equal ["-O", "0", "--jobs=#{jobs}"], SpinelTest::Unit::Toolchain.compile_flags
  end

  def cgroup(root, files, proc: "0::/\n")
    files.each do |rel, content|
      path = File.join(root, rel)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
    File.write(File.join(root, "proc_cgroup"), proc)
    SpinelTest::Unit::Toolchain.cpus(cgroup_root: root, proc_cgroup: File.join(root, "proc_cgroup"))
  end

  def test_cpus_without_quota
    Dir.mktmpdir do |root|
      assert_equal Etc.nprocessors, cgroup(root, { "cpu.max" => "max 100000\n" })
    end
  end

  def test_cpus_take_cgroup_v2_quota
    omit "needs more than 2 CPUs" if Etc.nprocessors <= 2
    Dir.mktmpdir do |root|
      assert_equal 2, cgroup(root, { "cpu.max" => "200000 100000\n" })
    end
  end

  def test_cpus_round_partial_quota_up
    omit "needs more than 2 CPUs" if Etc.nprocessors <= 2
    Dir.mktmpdir do |root|
      assert_equal 2, cgroup(root, { "cpu.max" => "150000 100000\n" })
    end
  end

  def test_cpus_take_tightest_quota_of_own_cgroup_and_ancestors
    omit "needs more than 2 CPUs" if Etc.nprocessors <= 2
    Dir.mktmpdir do |root|
      files = { "cpu.max" => "max 100000\n", "a/cpu.max" => "200000 100000\n", "a/b/cpu.max" => "max 100000\n" }
      assert_equal 2, cgroup(root, files, proc: "0::/a/b\n")
    end
  end

  def test_cpus_take_cgroup_v1_quota
    omit "needs more than 2 CPUs" if Etc.nprocessors <= 2
    Dir.mktmpdir do |root|
      files = { "cpu,cpuacct/cpu.cfs_quota_us" => "200000\n", "cpu,cpuacct/cpu.cfs_period_us" => "100000\n" }
      assert_equal 2, cgroup(root, files, proc: "")
    end
  end

  def test_cpus_ignore_unlimited_cgroup_v1_quota
    Dir.mktmpdir do |root|
      files = { "cpu,cpuacct/cpu.cfs_quota_us" => "-1\n", "cpu,cpuacct/cpu.cfs_period_us" => "100000\n" }
      assert_equal Etc.nprocessors, cgroup(root, files, proc: "")
    end
  end

  def test_cpus_never_exceed_nprocessors
    Dir.mktmpdir do |root|
      assert_equal Etc.nprocessors, cgroup(root, { "cpu.max" => "#{(Etc.nprocessors + 4) * 100000} 100000\n" })
    end
  end

  def test_nil_when_nothing_found
    Dir.mktmpdir do |dir|
      ENV["PATH"] = dir
      ENV.delete("SPINEL")
      assert_nil SpinelTest::Unit::Toolchain.spinel
    end
  end
end
