# frozen_string_literal: true

require_relative "lib/spinel_test/unit/version"

Gem::Specification.new do |spec|
  spec.name = "spinel_test-unit"
  spec.version = SpinelTest::Unit::VERSION
  spec.authors = ["Yuji Yaginuma"]
  spec.email = ["yuuji.yaginuma@gmail.com"]

  spec.summary = "An xUnit-style test framework for Spinel."
  spec.homepage = "https://github.com/y-yagi/spinel_test-unit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "prism", ">= 1.3", "< 2.0"
  spec.add_development_dependency "test-unit"
end
