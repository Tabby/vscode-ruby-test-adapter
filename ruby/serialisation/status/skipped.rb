# # frozen_string_literal: true

require "json"

module Serialisation
  module Status
    class Skipped < Base
      KEYS = %w[result test].freeze

      def initialize(test:)
        super(result: "skipped", test: test)
      end

      def json_keys
        KEYS
      end
    end
  end
end
