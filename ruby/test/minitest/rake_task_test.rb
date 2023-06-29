require_relative "test_helper"

FILES = {}

FILES["Rakefile"] = <<RUBY
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end
RUBY
FILES["lib/square.rb"] = <<RUBY
class Square
  def square_of(n)
    n * n
  end
end
RUBY
FILES["test/test_helper.rb"] = <<RUBY
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require "square"
require "minitest/autorun"

module TestHelper
end
RUBY
FILES["test/square_test.rb"] = <<RUBY
require_relative "test_helper"

class SquareTest < Minitest::Test
  def test_square_of_one
    assert_equal 1, Square.new.square_of(1)
  end

  def test_square_of_two
    assert_equal 3, Square.new.square_of(2)
  end

  def test_square_error
    raise
  end

  def test_square_skip
    skip "This is skip"
  end
end
RUBY

class RakeTaskTest < Minitest::Test
  include TestHelper

  attr_reader :dir

  def setup
    super
    @dir = Pathname(Dir.mktmpdir).realpath

    FILES.each do |path, content|
      path = dir + path

      path.parent.mkpath unless path.parent.directory?
      path.write(content)
    end
  end

  def env
    {
      "TESTS_DIR" => "test",
      "TESTS_PATTERN" => '*_test.rb'
    }
  end

  def test_test_list
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:minitest:list", chdir: dir.to_s)

    assert_equal "", stderr
    assert_predicate status, :success?

    assert_match(/START_OF_TEST_JSON(.*)END_OF_TEST_JSON/, stdout)

    stdout =~ /START_OF_TEST_JSON(.*)END_OF_TEST_JSON/
    json = JSON.parse($1, symbolize_names: true)

    [
      {
        id: "./test/square_test.rb[4]",
        label: "square of one",
        range: {
          start: { line: 3, character: 0 },
          end: { line: 3, character: 0 }
        },
        description: nil,
        sortText: "4",
        error: nil,
        tags: [],
        children: []
      },
      {
        id: "./test/square_test.rb[8]",
        label: "square of two",
        range: {
          start: { line: 7, character: 0 },
          end: { line: 7, character: 0 }
        },
        description: nil,
        sortText: "8",
        error: nil,
        tags: [],
        children: []
      },
      {
        id: "./test/square_test.rb[12]",
        label: "square error",
        range: {
          start: { line: 11, character: 0 },
          end: { line: 11, character: 0 }
        },
        description: nil,
        sortText: "12",
        error: nil,
        tags: [],
        children: []
      },
      {
        id: "./test/square_test.rb[16]",
        label: "square skip",
        range: {
          start: { line: 15, character: 0 },
          end: { line: 15, character: 0 }
        },
        description: nil,
        sortText: "16",
        error: nil,
        tags: [],
        children: []
      }
    ].each do |expectation|
      assert_includes(json[:examples].map { |e| e.except(:uri) }, expectation)
    end
  end

  def test_test_run_all
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:minitest:run test", chdir: dir.to_s)

    refute_predicate status, :success?
    assert_equal "", stderr
    assert_match(/START_OF_TEST_JSON(.*)END_OF_TEST_JSON/, stdout)

    stdout =~ /START_OF_TEST_JSON(.*)END_OF_TEST_JSON/
    json = JSON.parse($1, symbolize_names: true)

    examples = json[:examples]

    assert_equal 4, examples.size

    assert_any(examples, pass_count: 1) do |example|
      assert_equal "errored", example[:result]
      assert_equal "square error", example.dig(:test, :label)
      assert_nil example.dig(:test, :error)
      refute_nil example[:message]
      # assert_equal "Minitest::UnexpectedError", example.dig(:exception, :class)
      assert_match(/RuntimeError:/, example.dig(:message, 0, :message))
      assert_equal 11, example.dig(:message, 0, :location, :range, :start, :line)
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal "passed", example[:result]
      assert_equal "square of one", example.dig(:test, :label)
      assert_nil example.dig(:test, :error)
      assert_nil example[:message]
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal "failed", example[:result]
      assert_equal "square of two", example.dig(:test, :label)
      assert_nil example.dig(:test, :error)
      refute_nil example[:message]
      # assert_equal "Minitest::Assertion", example.dig(:exception, :class)
      assert_match /Expected: 3\n  Actual: 4/, example.dig(:message, 0, :message)
      assert_equal "3", example.dig(:message, 0, :expectedOutput)
      assert_equal "4", example.dig(:message, 0, :actualOutput)
      assert_equal 7, example.dig(:message, 0, :location, :range, :start, :line)
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal "skipped", example[:result]
      assert_equal "square skip", example.dig(:test, :label)
      assert_equal "This is skip", example.dig(:test, :error)
      assert_nil example[:message]
    end
  end

  def test_test_run_file
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:minitest:run test/square_test.rb", chdir: dir.to_s)

    refute_predicate status, :success?
    assert_equal "", stderr
    assert_match(/START_OF_TEST_JSON(.*)END_OF_TEST_JSON/, stdout)

    stdout =~ /START_OF_TEST_JSON(.*)END_OF_TEST_JSON/
    json = JSON.parse($1, symbolize_names: true)

    examples = json[:examples]

    assert_equal 4, examples.size
  end

  def test_test_run_file_line
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:minitest:run test/square_test.rb:4 test/square_test.rb:16", chdir: dir.to_s)

    assert_predicate status, :success?
    assert_equal "", stderr
    assert_match(/START_OF_TEST_JSON(.*)END_OF_TEST_JSON/, stdout)

    stdout =~ /START_OF_TEST_JSON(.*)END_OF_TEST_JSON/
    json = JSON.parse($1, symbolize_names: true)

    examples = json[:examples]

    assert_equal 2, examples.size

    assert_any(examples, pass_count: 1) do |example|
      assert_equal "square of one", example[:test][:label]
      assert_equal "passed", example[:result]
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal "square skip", example[:test][:label]
      assert_equal "skipped", example[:result]
    end
  end
end
