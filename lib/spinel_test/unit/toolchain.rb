# frozen_string_literal: true

require "etc"

module SpinelTest
  module Unit
    # Finds the Spinel compiler.
    #
    #   1. SPINEL (a Spinel checkout, for example)
    #   2. spinel on PATH
    #   3. `mise which spinel` (mise is installed but not activated)
    module Toolchain
      def self.spinel
        env = ENV["SPINEL"]
        return env unless env.nil? || env.empty?

        find_on_path("spinel") || mise_which("spinel")
      end

      def self.compile_flags
        opt = ENV["SPINEL_TEST_UNIT_OPT"]
        opt = "0" if opt.nil? || opt.empty?
        jobs = ENV["SPINEL_TEST_UNIT_JOBS"]
        jobs = cpus.clamp(1, 16).to_s if jobs.nil? || jobs.empty?
        ["-O", opt, "--jobs=#{jobs}"]
      end

      def self.cpus(cgroup_root: "/sys/fs/cgroup", proc_cgroup: "/proc/self/cgroup")
        quota = cpu_quota(cgroup_root, proc_cgroup)
        quota ? [Etc.nprocessors, quota.ceil].min : Etc.nprocessors
      end

      def self.cpu_quota(root, proc_cgroup)
        quotas = cgroup_v2_dirs(root, proc_cgroup).filter_map do |dir|
          max, period = read_cgroup(File.join(dir, "cpu.max"))&.split
          max.to_f / period.to_f if max && max != "max" && period.to_f > 0
        end
        v1 = File.join(root, "cpu,cpuacct")
        quota = read_cgroup(File.join(v1, "cpu.cfs_quota_us")).to_f
        period = read_cgroup(File.join(v1, "cpu.cfs_period_us")).to_f
        quotas << quota / period if quota > 0 && period > 0
        quotas.min
      end

      def self.cgroup_v2_dirs(root, proc_cgroup)
        path = read_cgroup(proc_cgroup)&.lines&.find { |l| l.start_with?("0::") }
        path = path ? path.chomp.delete_prefix("0::") : "/"
        dirs = [root]
        path.split("/").reject(&:empty?).each { |part| dirs << File.join(dirs.last, part) }
        dirs
      end

      def self.read_cgroup(path)
        File.read(path)
      rescue StandardError
        nil
      end

      def self.find_on_path(name)
        ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |d| File.join(d, name) }
                   .find { |f| File.file?(f) && File.executable?(f) }
      end

      def self.mise_which(name)
        return nil unless find_on_path("mise")

        out = IO.popen(["mise", "which", name], err: File::NULL, &:read).strip
        $?.success? && !out.empty? ? out : nil
      end
    end
  end
end
