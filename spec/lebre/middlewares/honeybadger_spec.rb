# frozen_string_literal: true

require "spec_helper"
require "lebre/middlewares/honeybadger"

RSpec.describe Lebre::Middlewares::Honeybadger do
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo) }
  let(:metadata) { instance_double(Bunny::MessageProperties) }
  let(:payload) { "payload" }
  let(:honeybadger) do
    stub_const("Honeybadger", Class.new do
      def self.add_breadcrumb(*)
      end

      def self.notify(*)
      end
    end)
  end
  let(:middleware) do
    described_class.new(class_name: "MyConsumer")
  end
  let(:message) do
    Lebre::Message.new(delivery_info, metadata, payload)
  end

  it "returns the result of the downstream middleware" do
    result =
      middleware.call(message, proc { :moep })

    expect(result).to eq(:moep)
  end

  it "calls notify when an error is raised" do
    error = RuntimeError.new("moep")
    expect(honeybadger).to receive(:notify).with(error, context: {class_name: "MyConsumer"})

    expect do
      middleware.call(
        message,
        proc { raise error }
      )
    end.to raise_error(error)
  end
end
