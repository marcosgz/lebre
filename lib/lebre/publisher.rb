# frozen_string_literal: true

module Lebre
  class Publisher
    DEFAULT_EXCHANGE_OPTIONS = {type: :topic, durable: true, auto_delete: false}.freeze
    DEFAULT_PUBLISH_OPTIONS = {expiration: 7 * (60 * 60 * 24), content_type: "application/json"}.freeze

    def initialize(exchange_name, **options)
      @exchange_name = "pipeline.#{exchange_name}"
      @exchange_options = DEFAULT_EXCHANGE_OPTIONS.merge(options)
    end

    def publish(message, **options)
      bunny.with_channel do |channel|
        exchange = channel.exchange(@exchange_name, @exchange_options)
        exchange.publish(message.to_json, DEFAULT_PUBLISH_OPTIONS.merge(options))
      end
    end

    def bunny
      Thread.current[:lebre_bunny] ||= Lebre.config.create_connection(suffix: "publisher")
    end
  end
end
