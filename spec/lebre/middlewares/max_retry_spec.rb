# frozen_string_literal: true

require "spec_helper"

require "lebre/middlewares/max_retry"

RSpec.describe Lebre::Middlewares::MaxRetry do
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo) }
  let(:metadata) do
    instance_double(
      Bunny::MessageProperties,
      headers: {
        "x-death" => [
          {
            "count" => 10,
            "exchange" => "",
            "queue" => "my_queue.retry",
            "reason" => "expired",
            "routing-keys" => ["my_queue.retry"],
            "time" => Time.parse("2024-09-10T10:56:22Z")
          },
          {
            "count" => 2,
            "reason" => "rejected",
            "queue" => "my_queue",
            "time" => Time.parse("2024-09-10T10:56:20Z"),
            "exchange" => "my_exchange",
            "routing-keys" => [""]
          }
        ]
      }
    )
  end
  let(:payload) { "payload" }
  let(:error_queue) { "my_queue.error" }
  let(:middleware) do
    described_class.new(
      retries: max_retries, error_queue: error_queue
    )
  end
  let(:max_retries) { 2 }
  let(:channel) { instance_double(Bunny::Channel) }
  let(:default_exchange) { instance_double(Bunny::Exchange) }
  let(:message) do
    Lebre::Message.new(delivery_info, metadata, payload)
  end

  before do
    allow(delivery_info).to receive(:channel).and_return(channel)

    allow(Bunny::Exchange).to receive(:default).and_return(default_exchange)
  end

  context "when retry count is not exceeded" do
    it "returns the result of the downstream middleware" do
      expect(
        middleware.call(message, proc { :moep })
      ).to eq(:moep)
    end
  end

  context "when retry count is exceeded" do
    let(:max_retries) { 1 }

    it "acks the message when the max retry count is exceeded" do
      allow(default_exchange).to receive(:publish)

      expect(
        middleware.call(message, proc { :moep })
      ).to eq(:ack)
    end

    it "publishes the message to the configured error exchange" do
      expect(Bunny::Exchange).to receive(:default).with(channel).and_return(
        default_exchange
      )
      expect(default_exchange).to receive(:publish).with(
        payload,
        routing_key: error_queue
      )

      middleware.call(message, proc { :moep })
    end
  end

  context "when no death headers are present" do
    let(:metadata) { instance_double(Bunny::MessageProperties, headers: {}) }

    it "returns downstream result if no death headers are present" do
      expect(
        middleware.call(message, proc { :moep })
      ).to eq(:moep)
    end
  end

  context "when metadata has no headers" do
    let(:metadata) { instance_double(Bunny::MessageProperties, headers: nil) }

    it "returns downstream result if no death headers are present" do
      expect(
        middleware.call(message, proc { :moep })
      ).to eq(:moep)
    end
  end
end
