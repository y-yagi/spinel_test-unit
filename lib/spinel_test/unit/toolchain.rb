# frozen_string_literal: true

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
