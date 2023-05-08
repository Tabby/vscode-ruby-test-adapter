# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Failed < Base
      KEYS = %w[result test duration message].freeze

      def initialize(test:, message:, duration: nil)
        super(result: "failed", test: test, message: message, duration: duration)
      end

      def json_keys
        KEYS
      end
    end
  end
end
