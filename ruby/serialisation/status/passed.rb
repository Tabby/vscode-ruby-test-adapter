# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Passed < Base
      KEYS = %w[result test_id test_item duration].freeze

      def initialize(test_id:, test_item: nil, duration: nil)
        super(result: "passed", test_id: test_id, test_item: test_item, duration: duration)
      end

      def json_keys
        KEYS
      end
    end
  end
end
