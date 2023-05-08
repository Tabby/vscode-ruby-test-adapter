# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Base
      def initialize(result:, test:, duration: nil, message: [])
        raise ArgumentError, "test must be a TestItem" unless test.is_a?(Serialisation::TestItem)
        if duration
          raise ArgumentError, "duration must be a number" unless duration.is_a?(Numeric)
        end
        if message
          raise ArgumentError, "message must be an array of TestMessage" unless message.is_a?(Array)
          raise ArgumentError, "message must be an array of TestMessage" unless message.all?{ |m| m.is_a?(Serialisation::Status::TestMessage) }
        end

        @result = result
        @test = test
        @duration = duration
        @message = message
      end

      attr_reader :result, :test, :duration, :message

      def json_keys
        raise "Not implemented"
      end

      def as_json(*)
        {
          "result" => result,
          "test" => test.as_json,
          "duration" => duration,
          "message" => message.map(&:as_json),
      }.slice(*json_keys)
      end

      def to_json(*args)
        as_json.to_json(*args)
      end
    end
  end
end
