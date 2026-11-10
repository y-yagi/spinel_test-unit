# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "scanner"
require_relative "generator"
require_relative "toolchain"

module SpinelTest
  module Unit
    # spinel_test-unit [PATH...] [-n NAME] [-t CLASS] [-I DIR] [--ruby]
    #
    # Scans the test files with Prism, generates a main.rb that calls every
    # test, compiles it with Spinel and runs the binary. With --ruby it runs the
    # generated main.rb with the current Ruby instead, so one test file can be
    # checked under both.
    class CLI
      def self.start(argv, root: Dir.pwd)
        new(argv, root: root).run
      end

      def initialize(argv, root: Dir.pwd)
        @root = File.expand_path(root)
        @paths = []
        @filter = nil
        @testcase = nil
        @ruby = false
        @includes = []
        @exit = nil
        parse(argv.dup)
      end

      USAGE = <<~TEXT
        Usage: spinel_test-unit [PATH...] [-n NAME] [-t CLASS] [-I DIR] [--ruby]

        Compiles the tests with Spinel and runs them (with --ruby, runs them with the
        current Ruby instead).

          PATH             test file or directory (default: test)
          -n, --name NAME  run only the tests whose "Class#test_name" includes NAME,
                           or matches it when NAME is /regexp/
          -t, --testcase CLASS
                           run only the tests of the class named CLASS (exact match),
                           or whose class name matches it when CLASS is /regexp/
          -I DIR           add DIR to the load path (repeatable)
          --ruby           run with the current Ruby instead of compiling with Spinel
          -h, --help       show this help
      TEXT

      def run
        return @exit if @exit

        files = test_files
        if files.empty?
          warn "spinel_test-unit: no test files found"
          return 1
        end

        unless @ruby
          spinel = find_spinel
          return 1 unless spinel
        end

        entries = build_entries(files)
        if entries.empty?
          warn "spinel_test-unit: no tests found"
          return 1
        end

        Dir.mktmpdir("spinel_test-unit") do |dir|
          main = File.join(dir, "main.rb")
          File.write(main, Generator.generate(entries, @root))
          @ruby ? run_with_ruby(main, entries) : run_with_spinel(spinel, main, dir, entries)
        end
      end

      private

      def find_spinel
        spinel = Toolchain.spinel
        warn "spinel_test-unit: Spinel not found (set SPINEL, put spinel on PATH, or install it with mise)" if spinel.nil?
        spinel
      end

      def run_with_spinel(spinel, main, dir, entries)
        bin = File.join(dir, "testbin")
        return 1 unless compile(spinel, main, bin, entries)

        run_command([bin])
      end

      def run_with_ruby(main, entries)
        load_path = include_dirs(entries).flat_map { |dir| ["-I", dir] }
        run_command([RbConfig.ruby] + load_path + [main])
      end

      def run_command(command)
        args = []
        args += ["-n", @filter] if @filter
        args += ["-t", @testcase] if @testcase
        system(*command, *args) ? 0 : ($?.exitstatus || 1)
      end

      def parse(args)
        until args.empty?
          arg = args.shift
          case arg
          when "-h", "--help"
            puts USAGE
            @exit = 0
            return
          when "-n", "--name"
            return usage_error("#{arg} requires a value") if args.empty?

            @filter = args.shift
            return unless valid_pattern?(@filter)
          when "-t", "--testcase"
            return usage_error("#{arg} requires a value") if args.empty?

            @testcase = args.shift
            return unless valid_pattern?(@testcase)
          when "--ruby" then @ruby = true
          when "-I"
            return usage_error("-I requires a value") if args.empty?

            @includes << File.expand_path(args.shift, @root)
          when /\A-I(.+)\z/ then @includes << File.expand_path($1, @root)
          when /\A--name=(.*)\z/
            @filter = $1
            return unless valid_pattern?(@filter)
          when /\A--testcase=(.*)\z/
            @testcase = $1
            return unless valid_pattern?(@testcase)
          when "--" then @paths.concat(args.shift(args.size))
          when /\A-/ then return usage_error("unknown option: #{arg}")
          else @paths << arg
          end
        end
      end

      def valid_pattern?(value)
        return true unless value.length >= 2 && value.start_with?("/") && value.end_with?("/")

        Regexp.new(value[1..-2])
        true
      rescue RegexpError => e
        usage_error("invalid regexp #{value}: #{e.message}")
        false
      end

      def usage_error(message)
        warn "spinel_test-unit: #{message}"
        warn USAGE
        @exit = 2
      end

      def test_files
        paths = @paths.empty? ? ["test"] : @paths
        paths.flat_map do |path|
          full = File.expand_path(path, @root)
          if File.directory?(full)
            # fixtures/ below the given directory are skipped, unless the
            # directory itself is inside fixtures/ (paths relative to @root,
            # so where the project lives does not matter)
            skip = !in_fixtures?(full)
            (Dir.glob(File.join(full, "**", "*_test.rb")) + Dir.glob(File.join(full, "**", "test_*.rb")))
              .reject { |f| skip && in_fixtures?(File.dirname(f)) }
          elsif File.file?(full)
            [full]
          else
            warn "spinel_test-unit: #{path}: no such file or directory"
            []
          end
        end.uniq.sort
      end

      def build_entries(files)
        sources = {}
        (context_files + files).uniq.each { |f| sources[f] = File.read(f) }
        add_required_files(sources)
        result = Scanner.scan_files(sources, files)
        result.warnings.each do |file, name, parent|
          warn "spinel_test-unit: #{display(file)}: #{name} inherits from #{parent}, which is not defined in a scanned file; its tests are ignored"
        end

        result.classes.each { |c| c.locations.transform_values! { |location| display(location) } }
        by_file = result.classes.group_by(&:file)
        order = []
        files.each do |file|
          next unless by_file[file]

          by_file[file].each { |c| (c.files || [file]).each { |f| order << f } }
        end
        order.uniq.map do |file|
          { file: file, require: require_name(file), classes: by_file[file] || [] }
        end
      end

      # Follows string-literal require / require_relative transitively from the
      # already collected files and adds the files found (e.g. a base test
      # class provided by a library on an -I path) as scan-only context.
      def add_required_files(sources)
        gem_lib = File.expand_path("../..", __dir__) + File::SEPARATOR
        dirs = [File.join(@root, "lib"), File.join(@root, "test"), @root] + @includes
        dirs = dirs.select { |d| File.directory?(d) }.uniq
        queue = sources.keys
        until queue.empty?
          file = queue.shift
          Scanner.requires(sources[file]).each do |kind, name|
            found = resolve_require(kind, name, file, dirs)
            next if found.nil? || sources.key?(found) || found.start_with?(gem_lib)

            begin
              sources[found] = File.read(found)
            rescue SystemCallError
              next
            end
            queue << found
          end
        end
      end

      def resolve_require(kind, name, from, dirs)
        name += ".rb" unless name.end_with?(".rb")
        candidates = if kind == :relative || name.start_with?("./", "../")
          [File.expand_path(name, File.dirname(from))]
        elsif name.start_with?("/")
          [name]
        else
          ([File.dirname(from)] + dirs).map { |d| File.expand_path(name, d) }
        end
        candidates.find { |c| File.file?(c) }
      end

      def context_files
        dir = File.join(@root, "test")
        Dir.glob(File.join(dir, "**", "*.rb")).reject { |f| in_fixtures?(File.dirname(f)) }.sort
      end

      # True if the directory path, relative to @root, has a fixtures component.
      def in_fixtures?(dir)
        rel = dir.start_with?(@root + File::SEPARATOR) ? dir.delete_prefix(@root + File::SEPARATOR) : dir
        rel.split(File::SEPARATOR).include?("fixtures")
      end

      def display(file)
        prefix = @root + File::SEPARATOR
        file.start_with?(prefix) ? file.delete_prefix(prefix) : file
      end

      def require_name(file)
        prefix = @root + File::SEPARATOR
        if file.start_with?(prefix)
          rel = file.delete_prefix(prefix)
        else
          # outside the root: use the name relative to the deepest -I dir
          dir = @includes.select { |d| file.start_with?(d + File::SEPARATOR) }.max_by(&:size)
          rel = dir ? file.delete_prefix(dir + File::SEPARATOR) : File.basename(file)
        end
        rel.delete_suffix(".rb")
      end

      def include_dirs(entries)
        gem_lib = File.expand_path("../..", __dir__)
        dirs = [File.join(@root, "lib"), File.join(@root, "test"), @root, gem_lib] + @includes
        entries.each { |e| dirs << File.dirname(e[:file]) unless e[:file].start_with?(@root + File::SEPARATOR) }
        dirs.select { |d| File.directory?(d) }.uniq
      end

      def compile(spinel, main, bin, entries)
        cmd = [spinel] + Toolchain.compile_flags + include_dirs(entries).flat_map { |d| ["-I", d] } + [main, "-o", bin]
        begin
          output, status = Open3.capture2e(*cmd)
        rescue SystemCallError => e
          hint = ENV["SPINEL"].to_s.empty? ? "" : " (check SPINEL)"
          warn "spinel_test-unit: cannot run Spinel: #{e.message}#{hint}"
          return false
        end
        unless status.success?
          warn output unless output.empty?
          warn "spinel_test-unit: compilation failed (#{cmd.join(" ")})"
        end
        status.success?
      end
    end
  end
end
