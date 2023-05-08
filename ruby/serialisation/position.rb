# # frozen_string_literal: true

require "json"

module Serialisation
  class Position
    def initialize(line:, character: 0)
      raise ArgumentError, "line must be an integer" unless line.is_a?(Integer)
      raise ArgumentError, "character must be an integer" unless character.is_a?(Integer)

      @line = line
      @character = character
    end

    attr_reader :line, :character

    def as_json(*)
      {
        "line" => line,
        "character" => character,
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end
  end
end
