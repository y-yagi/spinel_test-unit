# frozen_string_literal: true

require "prism"

module SpinelTest
  module Unit
    class Scanner
      VISIBILITY = %i[private protected public].freeze
      BASE_NAMES = ["SpinelTest::Unit::TestCase", "::SpinelTest::Unit::TestCase"].freeze

      TestClass = Struct.new(:name, :methods, :file, :files, keyword_init: true)
      # superclass is the raw name as written; scope is the lexical namespace it
      # was written in. Both are qualified in resolve, once every class is known.
      ClassInfo = Struct.new(:name, :superclass, :methods, :files, :hidden, :scope)
      Result = Struct.new(:classes, :warnings, keyword_init: true)

      def self.scan(sources)
        new.scan(sources)
      end

      def self.scan_files(sources, targets)
        new.scan_files(sources, targets)
      end

      # String-literal require / require_relative calls in source:
      # [[:require | :relative, "name"], ...]. Unparseable source yields [].
      def self.requires(source)
        found = []
        collect_requires(Prism.parse(source).value, found)
        found
      end

      def self.collect_requires(node, found)
        if node.is_a?(Prism::CallNode) && node.receiver.nil? &&
           (node.name == :require || node.name == :require_relative)
          arg = node.arguments&.arguments
          if arg && arg.size == 1 && arg[0].is_a?(Prism::StringNode)
            found << [node.name == :require ? :require : :relative, arg[0].unescaped]
          end
        end
        node.compact_child_nodes.each { |child| collect_requires(child, found) }
      end

      def initialize
        @classes = {}
        @file = nil
      end

      def scan(sources)
        Array(sources).each { |source| visit(Prism.parse(source).value, []) }
        resolve
      end

      def scan_files(sources, targets)
        sources.each do |path, source|
          @file = path
          visit(Prism.parse(source).value, [])
        end
        classes = resolve(targets).select { |c| targets.include?(c.file) }
        Result.new(classes: classes, warnings: unresolved_warnings(targets))
      end

      private

      def visit(node, namespace)
        case node
        when Prism::ModuleNode
          visit(node.body, namespace + [path_name(node.constant_path)]) if node.body
        when Prism::ClassNode
          name = (namespace + [path_name(node.constant_path)]).join("::")
          info = (@classes[name] ||= ClassInfo.new(name, nil, [], []))
          info.files << @file if @file && !info.files.include?(@file)
          if node.superclass
            info.superclass = path_name(node.superclass)
            info.scope = namespace
          end
          collect_methods(node.body, info)
          visit(node.body, name.split("::")) if node.body
        when Prism::ProgramNode
          visit(node.statements, namespace)
        when Prism::StatementsNode
          node.body.each { |child| visit(child, namespace) }
        end
      end

      def collect_methods(body, info)
        return unless body.is_a?(Prism::StatementsNode)

        hidden = false
        body.body.each do |stmt|
          if stmt.is_a?(Prism::CallNode) && stmt.receiver.nil? && VISIBILITY.include?(stmt.name)
            if stmt.arguments.nil?
              hidden = stmt.name != :public
            elsif stmt.name != :public
              # private def test_x / private :test_x
              stmt.arguments.arguments.each do |arg|
                name = arg.is_a?(Prism::DefNode) ? arg.name.to_s : (arg.is_a?(Prism::SymbolNode) ? arg.unescaped : nil)
                info.methods.delete(name) if name
                (info.hidden ||= []) << name if name
              end
            end
            next
          end
          next if hidden
          next unless stmt.is_a?(Prism::DefNode) && stmt.receiver.nil?

          name = stmt.name.to_s
          next if info.hidden&.include?(name)

          info.methods << name if name.start_with?("test_") && !info.methods.include?(name)
        end
      end

      def path_name(node)
        return nil if node.nil?

        case node
        when Prism::ConstantReadNode then node.name.to_s
        when Prism::ConstantPathNode
          parent = node.parent ? path_name(node.parent) : ""
          "#{parent}::#{node.name}"
        end
      end

      # Qualified superclass name of info (nil if none), resolved against all
      # scanned classes, so the result does not depend on definition order.
      def superclass_of(info)
        name = info.superclass
        return nil if name.nil?
        return name if BASE_NAMES.include?(name)
        return name.delete_prefix("::") if name.start_with?("::")

        scope = info.scope || []
        scope.size.downto(0) do |n|
          candidate = (scope.first(n) + [name]).join("::")
          return candidate if @classes.key?(candidate)
        end
        name
      end

      def resolve(targets = nil)
        @classes.values.filter_map do |info|
          chain = ancestry(info)
          next unless chain

          methods = chain.reverse.flat_map(&:methods).uniq
          next if methods.empty?

          files = chain.reverse.flat_map(&:files).uniq
          file = (targets && info.files.find { |f| targets.include?(f) }) || info.files.first
          TestClass.new(name: info.name, methods: methods, file: file, files: files)
        end
      end

      def unresolved_warnings(targets)
        @classes.values.filter_map do |info|
          next if info.methods.empty? || !info.files.any? { |f| targets.include?(f) }
          next if ancestry(info)

          parent = missing_parent(info)
          [info.files.find { |f| targets.include?(f) }, info.name, parent] if parent
        end
      end

      def missing_parent(info)
        seen = {}
        current = info
        while current && !seen[current.name]
          seen[current.name] = true
          sup = superclass_of(current)
          return nil if sup.nil? || BASE_NAMES.include?(sup)
          return sup unless @classes[sup]

          current = @classes[sup]
        end
        nil
      end

      def ancestry(info)
        chain = []
        current = info
        seen = {}
        while current
          return nil if seen[current.name]

          seen[current.name] = true
          chain << current
          sup = superclass_of(current)
          return chain if BASE_NAMES.include?(sup)

          current = sup && @classes[sup]
        end
        nil
      end
    end
  end
end
