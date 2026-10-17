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

  def test_nil_when_nothing_found
    Dir.mktmpdir do |dir|
      ENV["PATH"] = dir
      ENV.delete("SPINEL")
      assert_nil SpinelTest::Unit::Toolchain.spinel
    end
  end
end
