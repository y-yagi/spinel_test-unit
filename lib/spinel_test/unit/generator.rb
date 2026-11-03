# frozen_string_literal: true

module SpinelTest
  module Unit
    module Generator
      # files: [{ require: "test/foo_test", classes: [TestClass, ...] }, ...]
      # root: the directory the failure locations are shown relative to.
      def self.generate(files, root = "")
        out = +"require \"spinel_test/unit\"\n"
        files.each { |f| out << "require #{f[:require].dump}\n" }
        out << ARGV_PARSER
        out << "runner = SpinelTest::Unit::Runner.new(filter, #{root.dump})\n"
        files.each do |f|
          f[:classes].each do |klass|
            locations = klass.locations || {}
            klass.methods.each do |m|
              out << "t = #{klass.name}.new\n"
              out << "runner.run(#{"#{klass.name}##{m}".dump}, t, #{locations[m].to_s.dump}) { t.#{m} }\n"
            end
          end
        end
        out << "exit runner.finish\n"
        out
      end

      ARGV_PARSER = <<~RUBY
        filter = ""
        i = 0
        while i < ARGV.length
          if ARGV[i] == "-n" && i + 1 < ARGV.length
            filter = ARGV[i + 1]
            i += 1
          end
          i += 1
        end
      RUBY
    end
  end
end
