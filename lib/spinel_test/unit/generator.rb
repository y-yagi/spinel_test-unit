# frozen_string_literal: true

module SpinelTest
  module Unit
    module Generator
      # files: [{ require: "test/foo_test", classes: [TestClass, ...] }, ...]
      def self.generate(files)
        out = +"require \"spinel_test/unit\"\n"
        files.each { |f| out << "require #{f[:require].dump}\n" }
        out << ARGV_PARSER
        out << "runner = SpinelTest::Unit::Runner.new(filter)\n"
        files.each do |f|
          f[:classes].each do |klass|
            klass.methods.each do |m|
              out << "t = #{klass.name}.new\n"
              out << "runner.run(#{"#{klass.name}##{m}".dump}, t) { t.#{m} }\n"
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
