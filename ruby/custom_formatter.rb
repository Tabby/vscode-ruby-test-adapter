# frozen_string_literal: true

require 'json'
require 'rspec/core'
require 'rspec/core/formatters/base_formatter'
# require 'rspec/expectations'
require_relative "serialisation/location"
require_relative "serialisation/position"
require_relative "serialisation/range"
require_relative "serialisation/status/base"
require_relative "serialisation/status/enqueued"
require_relative "serialisation/status/errored"
require_relative "serialisation/status/failed"
require_relative "serialisation/status/passed"
require_relative "serialisation/status/skipped"
require_relative "serialisation/status/started"
require_relative "serialisation/status/test_message"
require_relative "serialisation/test_item"

# Formatter to emit RSpec test status information in the required format for the extension
class CustomFormatter < RSpec::Core::Formatters::BaseFormatter
  RSpec::Core::Formatters.register self,
                                   :message,
                                   :deprecation,
                                   :dump_summary,
                                   :stop,
                                   :seed,
                                   :close,
                                   :example_group_started,
                                   :example_passed,
                                   :example_failed,
                                   :example_pending,
                                   :example_started

  attr_reader :output_hash

  def initialize(output)
    super
    @test_items = {}
    @group_items = {}
    @output_hash = {
      version: RSpec::Core::Version::STRING
    }
  end

  def message(notification)
    (@output_hash[:messages] ||= []) << notification.message
  end

  def deprecation(notification)
    # TODO
    # DeprecationNotification methods:
    # - call_site
    # - deprecated/message
    # - replacement
    $stderr.puts "\ndeprecation:\n\tcall_site:#{notification.call_site}\n\tmessage:#{notification.message}\n\treplacement:#{notification.replacement}"
    super(notification)
  end

  def dump_summary(summary)
    @output_hash[:summary] = {
      duration: summary.duration,
      example_count: summary.example_count,
      failure_count: summary.failure_count,
      pending_count: summary.pending_count,
      errors_outside_of_examples_count: summary.errors_outside_of_examples_count
    }
    @output_hash[:summary_line] = summary.totals_line
  end

  def stop(notification)
    # @output_hash[:examples] = notification.examples.map do |example|
    #   format_example(example).tap do |hash|
    #     e = example.exception
    #     if e
    #       hash[:exception] = {
    #         class: e.class.name,
    #         message: e.message,
    #         backtrace: e.backtrace,
    #         position: exception_position(e.backtrace_locations, example.metadata)
    #       }
    #     end
    #   end
    # end
    @output_hash[:examples] = @test_items.values.map(&:as_json)
  end

  def seed(notification)
    return unless notification.seed_used?

    @output_hash[:seed] = notification.seed
  end

  def close(_notification)
    output.write "START_OF_TEST_JSON#{@output_hash.to_json}END_OF_TEST_JSON\n"
  end

  def example_passed(notification)
    # output.write "PASSED: #{notification.example.id}\n"
    output.write "#{passed_status(notification.example).to_json}\n"
  end

  def example_failed(notification)
    # klass = notification.example.exception.class
    # status = exception_is_error?(klass) ? 'ERRORED' : 'FAILED'
    # exception_message = notification.example.exception.message.gsub(/\s+/, ' ').strip
    # output.write "#{status}(#{klass.name}:#{exception_message}): " \
    #              "#{notification.example.id}\n"
    # # This isn't exposed for simplicity, need to figure out how to handle this later.
    # # output.write "#{notification.exception.backtrace.to_json}\n"
    output.write "#{failed_status(notification.example).to_json}\n"
  end

  def example_pending(notification)
    # output.write "SKIPPED: #{notification.example.id}\n"
    output.write "#{skipped_status(notification.example).to_json}\n"
  end

  def example_started(notification)
    # output.write "RUNNING: #{notification.example.id}\n"
    # dump_notification(notification)
    output.write "#{started_status(notification.example).to_json}\n"
  end

  def example_group_started(notification)
    # output.write "RUNNING: #{notification.group.id}\n"
    # dump_notification(notification)

    item = create_group_item(notification.group)
    output.write "#{::Serialisation::Status::Started.new(test: item).to_json}\n"
  end

  private

  # Properties of example:

  # def format_example(example)
  #   # dump_example(example)
  #   {
  #     id: example.id,
  #     description: example.description,
  #     full_description: example.full_description,
  #     status: example_status(example),
  #     file_path: example.metadata[:file_path],
  #     line_number: example.metadata[:line_number],
  #     type: example.metadata[:type],
  #     pending_message: example.execution_result.pending_message,
  #     duration: example.execution_result.run_time
  #   }
  # end

  def exception_location(backtrace, metadata)
    frame = backtrace.find { |frame| frame.path.end_with?(metadata[:file_path]) }
    if frame
      line = frame.lineno
    else
      line = metadata[:line_number] ? metadata[:line_number] : 1
    end

    ::Serialisation::Location.new(
      uri: URI.parse("file:///#{metadata[:absolute_file_path]}"),
      range: ::Serialisation::Range.new(start_pos: ::Serialisation::Position.new(line: line - 1)),
    )
  end

  def example_status(example)
    if example.exception
      failed_status(example)
    elsif example.execution_result.status == :pending
      skipped_status(example)
    else
      passed_status(example)
    end
  end

  def started_status(example)
    ::Serialisation::Status::Started.new(test: test_item(example))
  end

  def failed_status(example)
    klass = exception_is_error?(example.exception.class) ? ::Serialisation::Status::Errored : ::Serialisation::Status::Failed
    klass.new(
      test: test_item(example),
      message: test_message(example),
      duration: example.execution_result.run_time,
    )
  end

  def skipped_status(example)
    item = test_item(example)
    # Not sure if there's a better place to put this message
    item.error = example.execution_result.pending_message,
    ::Serialisation::Status::Skipped.new(test: item)
  end

  def passed_status(example)
    ::Serialisation::Status::Passed.new(
      test: test_item(example),
      duration: example.execution_result.run_time,
    )
  end

  def exception_is_error?(exception_class)
    !exception_class.to_s.start_with?('RSpec')
  end

  def multiple_exception_container?(exception)
    exception.is_a? RSpec::Core::MultipleExceptionError
    # || exception.is_a? RSpec::Expectations::MultipleExpectationsNotMetError
  end

  def test_message(example)
    if multiple_exception_container? example.exception
      example.exception.all_exceptions.map do |sub_exception|
        test_message_from_exception(example, sub_exception)
      end
    else
      [test_message_from_exception(example, example.exception)]
    end
  end

  def test_message_from_exception(example, exception)
    msg = ::Serialisation::Status::TestMessage.new(
      message: "#{exception.message}\n#{exception.backtrace.join("\n")}",
      location: exception_location(backtrace, example.metadata)
    )

    # diff_match = err.message.match(ASSERTION_REGEX)
    # if diff_match
    #   msg.expected_output = diff_match[:exp]
    #   msg.actual_output = diff_match[:act]
    # end

    msg
  end

  def file_item(file_path, absolute_file_path)
    return @test_items[file_path] if @test_items.key?(file_path)

    item = ::Serialisation::TestItem.new(
      id: file_path,
      label: file_path.split('/').last,
      uri: URI.parse("file:///#{absolute_file_path}"),
      range: ::Serialisation::Range.new(
        start_pos: ::Serialisation::Position.new(line: 0),
      ),
      sort_text: file_path,
      parent_ids: item_parents(file_path),
    )
    @test_items[file_path] = item
    item
  end

  def create_group_item(group)
    scoped_id = group.metadata[:scoped_id]
    # puts "\ncreate_group_item - scoped_id: #{scoped_id}"
    parent_item = file_item(group.file_path, group.metadata[:absolute_file_path])
    # puts "\ncreate_group_item - parent: #{parent_item.inspect}"

    if scoped_id != "1"
      # Need to create child items for groups within file
      # puts "\ncreate_group_item - creating new group item"
      item = nil

      for i in 1..scoped_id.count(':') do
        sub_id = "[#{scoped_id[0..(2 * i)]}]"
        item = parent_item.children.find { |x| x.id.end_with?(sub_id)}
        # puts "\ncreate_group_item - parent(#{sub_id}): #{item.inspect}"

        if item.nil?
          item = ::Serialisation::TestItem.new(
            id: group.id,
            label: group.description,
            uri: URI.parse("file:///#{group.metadata[:absolute_file_path]}"),
            range: ::Serialisation::Range.new(
              start_pos: ::Serialisation::Position.new(line: group.metadata[:line_number] - 1),
            ),
            sort_text: scoped_id
          )
          # puts "\ncreate_group_item - parent(#{sub_id}): created #{item.inspect}"
          parent_item.children << item
        end

        parent_item = item
      end
      # puts "\ncreate_group_item - item: #{item.inspect}"
    end

    example_group = group.example_group.to_s
    anon_index = (example_group =~ /::Anonymous/) - 1
    example_group_name = example_group[0..anon_index]
    # puts "\ncreate_group_item - example_group_name: #{example_group_name}"
    @group_items[example_group_name] = parent_item
    parent_item
  end

  # def base_path(example)
  #   path_segments = example.file_path.split('/')
  #   if path_segments.first == '.'
  #     path_segments.shift
  #   end
  #   index = (example.absolute_file_path =~ /#{path_segments.first}/) - 1
  #   example.absolute_file_path[0..index]
  # end

  def item_parents(file_path)
    path_segments = file_path.split('/')
    if path_segments.first == '.'
      path_segments.shift
    end
    path_segments[0..-2]
  end

  # def shared_example?(example)
  #   example.metadata[:shared_group_inclusion_backtrace].length > 1
  # end

  def test_item(example)
    # Standard metadata keys: (TODO - get tags by finding other keys)
    #   block
    #   description_args
    #   description
    #   full_description
    #   described_class
    #   file_path
    #   line_number
    #   location
    #   absolute_file_path
    #   rerun_file_path
    #   scoped_id
    #   type
    #   execution_result
    #   example_group
    #   shared_group_inclusion_backtrace
    #   last_run_status

    # puts "\nexample: #{example.inspect}"

    parent = @group_items[example.example_group.to_s]
    # puts "\ntest_item - parent: #{parent.inspect} (#{example.example_group})"

    item = parent.children.select { |x| x.id == example.id }.first
    # puts "\ntest_item - item: #{item.inspect}"
    return item if item

    # puts "\ntest_item - creating new test item"
    item = ::Serialisation::TestItem.new(
      id: example.id,
      label: example.description,
      description: example.full_description,
      uri: URI.parse("file:///#{example.metadata[:absolute_file_path]}"),
      range: ::Serialisation::Range.new(
        start_pos: ::Serialisation::Position.new(line: example.metadata[:line_number] - 1),
      ),
      sort_text: example.metadata[:scoped_id],
    )
    # puts "\ntest_item - item: #{item.inspect}"
    parent.children << item
    item
  end

  def dump_notification(notification)
    if notification.respond_to?(:example)
      dump_example(notification.example)
    else
      dump_example(notification.group, true)
    end
  end

  def dump_example(example, group = false)
    $stderr.puts "\nexample#{group ? " group" : ""}:"
    %i[
      id
      class
      described_class
      description
      execution_result
      example_group
      full_description
      file_path
      location
      metadata
    ].each do |prop|
      if (example.respond_to? prop)
        if prop == :execution_result
          $stderr.puts "\n\t#{prop}:"
          er = example.send(prop)
          %i[
            exception
            finished_at
            pending_exception
            pending_fixed
            pending_message
            run_time
            started_at
            status
          ].each do |sub_prop|
            $stderr.puts "\n\t\t#{sub_prop}: #{er.send(sub_prop)}"
          end
        elsif prop == :metadata
          metadata = example.send(prop)
          $stderr.puts "\n\t#{prop}: {"
          dump_metadata(metadata)
          $stderr.puts "\n\t}"
        else
          $stderr.puts "\n\t#{prop}: #{example.send(prop)}"
        end
      end
    end
  end

  def dump_metadata(metadata, indent = "\t\t")
    %i[
      absolute_file_path
      block
      described_class
      description_args
      description
      example_group
      file_path
      full_description
      last_run_status
      line_number
      location
      rerun_file_path
      scoped_id
      shared_group_inclusion_backtrace
    ].each do |sub_prop|
      if metadata.key? sub_prop
        if sub_prop == :example_group
          $stderr.puts "\n#{indent}#{sub_prop}: {"
          dump_metadata(metadata[sub_prop], "\t\t\t")
          $stderr.puts "\n#{indent}}"
        else
          $stderr.puts "\n#{indent}#{sub_prop}: #{metadata[sub_prop]},"
        end
      end
    end
  end
end
