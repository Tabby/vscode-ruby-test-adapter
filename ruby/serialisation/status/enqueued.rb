# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Enqueued < Base
      KEYS = %w[result test_id test_item].freeze

      def initialize(test_id:, test_item: nil)
        super(result: "enqueued", test_id: test_id, test_item: test_item)
      end

      def json_keys
        KEYS
      end
    end
  end
end
