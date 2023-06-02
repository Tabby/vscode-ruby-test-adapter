# frozen_string_literal: true

require "serialisation/location"
require "serialisation/position"
require "serialisation/range"
require "serialisation/status/base"
require "serialisation/status/enqueued"
require "serialisation/status/errored"
require "serialisation/status/failed"
require "serialisation/status/passed"
require "serialisation/status/skipped"
require "serialisation/status/started"
require "serialisation/status/test_message"
require "serialisation/test_item"
require "uri"

module VSCode
  module Minitest
    class Reporter < ::Minitest::Reporter
      attr_accessor :assertions, :count, :results, :start_time, :total_time, :failures, :errors, :skips

      ASSERTION_REGEX = /(?:(?<msg>.*)\.)?\s*Expected:? (?<exp>.*)\s*(?:Actual:|to be) (?<act>.*)/.freeze

      def initialize(io = $stdout, options = {})
        super
        io.sync = true if io.respond_to?(:"sync=")
        self.assertions = 0
        self.count      = 0
        self.results    = []
      end

      def start
        self.start_time = ::Minitest.clock_time
      end

      def prerecord(klass, meth)
        data = VSCode::Minitest.tests.find_by(klass: klass.to_s, method: meth)
        io.puts "#{::Serialisation::Status::Started.new(test: VSCode.test_item(data)).to_json}\n"
      end

      def record(result)
        self.count += 1
        self.assertions += result.assertions
        results << result
        data = vscode_result(result)

        io.puts "#{data.to_json}\n"
      end

      def report
        aggregate = results.group_by { |r| r.failure.class }
        aggregate.default = [] # dumb. group_by should provide this
        self.total_time = (::Minitest.clock_time - start_time).round(2)
        self.failures   = aggregate[::Minitest::Assertion].size
        self.errors     = aggregate[::Minitest::UnexpectedError].size
        self.skips      = aggregate[::Minitest::Skip].size
        json = ENV.key?('PRETTY') ? JSON.pretty_generate(vscode_data) : JSON.generate(vscode_data)
        io.puts "START_OF_TEST_JSON#{json}END_OF_TEST_JSON"
      end

      def passed?
        failures.zero?
      end

      def vscode_data
        {
          version: ::Minitest::VERSION,
          summary: {
            duration: total_time,
            example_count: assertions,
            failure_count: failures,
            pending_count: skips,
            errors_outside_of_examples_count: errors
          },
          summary_line: "Total time: #{total_time}, Runs: #{count}, Assertions: #{assertions}, " \
                        "Failures: #{failures}, Errors: #{errors}, Skips: #{skips}",
          examples: results.map { |r| vscode_result(r).as_json }
        }
      end

      def vscode_result(result)
        data = VSCode::Minitest.tests.find_by(klass: result.klass, method: result.name).dup
        test = VSCode.test_item(data)
        if result.skipped?
          # Not sure if there's a better place to put this message
          test.error = result.failure.message
          return ::Serialisation::Status::Skipped.new(test: test)
        elsif result.passed?
          return ::Serialisation::Status::Passed.new(test: test, duration: result.time)
        else
          msg = [vscode_test_message(result, data)]
          if result.failure.exception.class.name == ::Minitest::UnexpectedError.name
            return ::Serialisation::Status::Errored.new(test: test, message: msg, duration: result.time)
          else
            return ::Serialisation::Status::Failed.new(test: test, message: msg, duration: result.time)
          end
        end
      end

      def vscode_test_message(result, data)
        return if result.passed? || result.skipped?

        err = result.failure.exception
        backtrace = expand_backtrace(err.backtrace)
        msg = ::Serialisation::Status::TestMessage.new(
          message: "#{err.message}\n#{clean_backtrace(backtrace).join("\n")}",
          location: exception_location(backtrace, data)
        )

        diff_match = err.message.match(ASSERTION_REGEX)
        if diff_match
          msg.expected_output = diff_match[:exp]
          msg.actual_output = diff_match[:act]
        end

        msg
      end

      def expand_backtrace(backtrace)
        backtrace.map do |line|
          parts = line.split(':')
          parts[0] = File.expand_path(parts[0], VSCode.project_root)
          parts.join(':')
        end
      end

      def clean_backtrace(backtrace)
        backtrace.map do |line|
          next unless line.start_with?(VSCode.project_root.to_s)

          line[VSCode.project_root.to_s] = ''
          line.delete_prefix!('/')
          line.delete_prefix!('\\')
          line
        end
      end

      def exception_location(backtrace, data)
        frame = backtrace.find { |frame| frame.start_with?(data[:full_path]) }
        if frame
          path, line = frame.split(':')
        else
          path = data[:full_path]
          line = data[:line_number] ? data[:line_number] : 1
        end

        ::Serialisation::Location.new(
          uri: URI.parse("file:///#{path}"),
          range: ::Serialisation::Range.new(start_pos: ::Serialisation::Position.new(line: line - 1)),
        )
      end
    end
  end
end
