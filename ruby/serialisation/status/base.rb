# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Base
      def initialize(result:, test_id:, test_item: nil, duration: nil, message: [])
        raise ArgumentError, "test_id must be a String" unless test_id.is_a? String
        raise ArgumentError, "test_item must be a TestItem" unless test_item.nil? || test_item.is_a?(Serialisation::TestItem)
        if duration
          raise ArgumentError, "duration must be a number" unless duration.is_a?(Numeric)
        end
        if message
          raise ArgumentError, "message must be an array of TestMessage" unless message.is_a?(Array)
          raise ArgumentError, "message must be an array of TestMessage" unless message.all?{ |m| m.is_a?(Serialisation::Status::TestMessage) }
        end

        @result = result
        @test_id = test_id
        @test_item = test_item
        @duration = duration
        @message = message
      end

      attr_reader :result, :test_id, :test_item, :duration, :message

      def json_keys
        raise "Not implemented"
      end

      def as_json(*)
        {
          "result" => result,
          "test_id" => test_id,
          "test_item" => test_item&.as_json || nil,
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
