require "rake"
require "uri"
require "serialisation/position"
require "serialisation/range"
require "serialisation/test_item"

module VSCode
  module Minitest
    class Tests
      def all
        @all ||= begin
          load_files
          build_list
        end
      end

      def find_by(**filters)
        all.find do |test|
          test.values_at(*filters.keys) == filters.values
        end
      end

      def load_files
        # Take the tests dir in the format of `./test/` and turn it into `test`.
        test_dir = ENV['TESTS_DIR'] || './test/'
        test_dir = test_dir.gsub('./', '')
        test_dir = test_dir[0...-1] if test_dir.end_with?('/')
        $LOAD_PATH << VSCode.project_root.join(test_dir).to_s
        patterns = ENV.fetch('TESTS_PATTERN').split(',').map { |p| "#{test_dir}/**/#{p}" }
        file_list = Rake::FileList[*patterns]
        file_list.each { |path| require File.expand_path(path) }
      end

      def build_list
        if ::Minitest.respond_to?(:seed) && ::Minitest.seed.nil?
          ::Minitest.seed = (ENV['SEED'] || srand).to_i % 0xFFFF
        end

        tests = []
        ::Minitest::Runnable.runnables.map do |runnable|
          file_name = nil
          puts "runnable #{runnable.name}\n"
          file_tests = runnable.runnable_methods.map do |test_name|
            puts "test #{test_name}\n"
            path, line = runnable.instance_method(test_name).source_location
            unless file_name
              index = path.rindex(/[\\\/]/)
              file_name = path.slice(index + 1, path.length - index)
            end
            full_path = File.expand_path(path, VSCode.project_root)
            path = full_path.gsub(VSCode.project_root.to_s, ".")
            path = "./#{path}" unless path.match?(/^\./)
            description = test_name.gsub(/^test_[:\s]*/, "")
            description = description.tr("_", " ") unless description.match?(/\s/)

            puts "end\n"
            ::Serialisation::TestItem.new(
              id: test_name,
              label: description,
              uri: URI.parse("file:///#{full_path}"),
              range: ::Serialisation::Range.new(
                  start_pos: ::Serialisation::Position.new(line: line),
                  end_pos: ::Serialisation::Position.new(line: line),
                ),
              sort_text: line.to_s
            )
          end

          unless file_tests.length.zero?
            file_item = ::Serialisation::TestItem.new(
              id: file_name,
              label: file_name,
              uri: file_tests.first.uri,
              range: ::Serialisation::Range.new(
                start_pos: ::Serialisation::Position.new(line: 0),
                end_pos: ::Serialisation::Position.new(line: 0),
              ),
              children: file_tests,
            )
            tests << file_item
          end
        end
        tests
      end
    end
  end
end
