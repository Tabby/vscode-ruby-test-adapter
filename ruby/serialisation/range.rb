# # frozen_string_literal: true

require "json"

module Serialisation
  class Range
    def initialize(start_pos:, end_pos:)
      raise ArgumentError, "start_pos must be a Pos" unless start_pos.is_a?(Serialisation::Pos)
      raise ArgumentError, "end_pos must be a Pos" unless end_pos.is_a?(Serialisation::Pos)

      @start_pos = start_pos
      @end_pos = end_pos
    end

    attr_reader :start_pos, :end_pos

    def as_json(*)
      {
        "start" => start_pos.as_json,
        "end" => end_pos.as_json,
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end
  end
end
