# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Failed < Base
      KEYS = %w[result test_id test_item duration message].freeze

      def initialize(test_id:, message:, test_item: nil, duration: nil)
        super(result: "failed", test_id: test_id, test_item: test_item, message: message, duration: duration)
      end

      def json_keys
        KEYS
      end
    end
  end
end
