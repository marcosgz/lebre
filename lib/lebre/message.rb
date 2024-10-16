# frozen_string_literal: true

module Lebre
  class Message
    attr_reader :delivery_info, :metadata, :payload

    def initialize(delivery_info, metadata, payload)
      @delivery_info = delivery_info
      @metadata = metadata
      @payload = payload
    end

    def mutate(payload: nil, metadata: nil, delivery_info: nil)
      self.class.new(
        delivery_info || @delivery_info,
        metadata || @metadata,
        payload || @payload
      )
    end

    def to_h
      {
        delivery: delivery_info&.to_h,
        metadata: metadata&.to_h,
        payload: payload
      }
    end

    def eql?(other)
      other.is_a?(self.class) &&
        delivery_info == other.delivery_info &&
        metadata == other.metadata &&
        payload == other.payload
    end
    alias_method :==, :eql?
  end
end
