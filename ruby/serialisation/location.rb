# # frozen_string_literal: true

require "json"
require "uri"

module Serialisation
  class Location
    def initialize(uri:, range:)
      raise ArgumentError, "uri must be a URI" unless uri.is_a?(URI::Generic)
      raise ArgumentError, "range must be a Range" unless range.is_a?(Serialisation::Range)

      @uri = uri
      @range = range
    end

    attr_reader :uri, :range

    def as_json(*)
      {
        "uri" => uri.to_s,
        "range" => range.as_json,
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end
  end
end
