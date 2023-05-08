# # frozen_string_literal: true

require "json"
require "uri"

module Serialisation
  class TestItem
    def initialize(id:, label:, uri: , range:,
                   description: nil, sort_text: nil, error: nil, tags: [], children: [])
      raise ArgumentError, "id must be a String" unless id.is_a?(String)
      raise ArgumentError, "label must be a String" unless label.is_a?(String)
      raise ArgumentError, "uri must be a URI" unless uri.is_a?(URI::Generic)
      raise ArgumentError, "range must be a Range" unless range.is_a?(Serialisation::Range)
      if description
        raise ArgumentError, "description must be a String" unless description.is_a?(String)
      end
      if sort_text
        raise ArgumentError, "sort_text must be a String" unless sort_text.is_a?(String)
      end
      if error
        raise ArgumentError, "error must be a String" unless error.is_a?(String)
      end
      if tags
        raise ArgumentError, "tags must be an array of Strings" unless tags.is_a?(Array)
        raise ArgumentError, "tags must be an array of Strings" unless tags.all?{ |t| t.is_a?(String) }
      end
      if children
        raise ArgumentError, "children must be an array of TestItems" unless children.is_a?(Array)
        raise ArgumentError, "children must be an array of TestItems" unless children.all?{ |c| c.is_a?(TestItem) }
      end

      @id = id
      @label = label
      @uri = uri
      @range = range
      @description = description
      @sort_text = sort_text
      @error = error
      @tags = tags
      @children = children
    end

    attr_reader :id, :label, :uri, :range, :description, :sort_text, :error, :tags, :children

    def as_json(*)
      {
        "id" => id,
        "label" => label,
        "uri" => uri.to_s,
        "range" => range.as_json,
        "description" => description,
        "sortText" => sort_text,
        "error" => error,
        "tags" => tags,
        "children" => children.map(&:as_json),
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end
  end
end
