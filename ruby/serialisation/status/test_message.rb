# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class TestMessage
      def initialize(message:, location: nil, actual_output: nil, expected_output: nil)
        raise ArgumentError, "message must be a String" unless message.is_a?(String)
        if (location)
          raise ArgumentError, "location must be a Location" unless location.is_a?(Serialisation::Location)
        end
        if (actual_output)
          raise ArgumentError, "actual_output must be a String" unless actual_output.is_a?(String)
        end
        if (expected_output)
          raise ArgumentError, "expected_output must be a String" unless expected_output.is_a?(String)
        end

        @message = message
        @location = location
        @actual_output = actual_output
        @expected_output = expected_output
      end

      attr_reader :message, :location, :actual_output, :expected_output

      def as_json(*)
        {
          "message" => message,
          "location" => location&.as_json,
          "actualOutput" => actual_output,
          "expectedOutput" => expected_output,
        }
      end

      def to_json(*args)
        as_json.to_json(*args)
      end
    end
  end
end
