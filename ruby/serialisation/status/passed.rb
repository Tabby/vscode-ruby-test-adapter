# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Passed < Base
      KEYS = %w[result test duration].freeze

      def initialize(test:, duration: nil)
        super(result: "passed", test: test, duration: duration)
      end

      def json_keys
        KEYS
      end
    end
  end
end
