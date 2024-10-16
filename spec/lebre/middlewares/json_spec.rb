# frozen_string_literal: true

require "spec_helper"
require "lebre/middlewares/json"

RSpec.describe Lebre::Middlewares::JSON do
  describe "#call" do
    let(:middleware) { described_class.new(options) }
    let(:delivery_info) { instance_double(Bunny::DeliveryInfo) }
    let(:metadata) { instance_double(Bunny::MessageProperties) }
    let(:payload) { MultiJson.dump({my: "payload"}) }
    let(:error_handler) { proc { :error_handler_result } }
    let(:options) { {on_error: error_handler} }
    let(:message) do
      Lebre::Message.new(delivery_info, metadata, payload)
    end

    it "returns the result of the downstream middleware" do
      expect(
        middleware.call(message, proc { :moep })
      ).to eq(:moep)
    end

    it "calls the next middleware with a parsed payload" do
      expect do |b|
        proc =
          proc do |message, _block|
            expect(message.payload).to eq("my" => "payload")
            Proc.new(&b).call
          end
        middleware.call(message, proc)
      end.to yield_control
    end

    it "can optionally symbolize keys" do
      middleware =
        described_class.new(
          symbolize_keys: true,
          on_error: error_handler
        )
      expect do |b|
        proc =
          proc do |message, _block|
            expect(message.payload).to eq(my: "payload")
            Proc.new(&b).call
          end
        middleware.call(message, proc)
      end.to yield_control
    end

    context "when initialized without error handler" do
      let(:options) { {} }
      let(:payload) { "This is not JSON" }

      it "does not raise" do
        expect { middleware }.not_to raise_error
      end

      it "rejects when encountering an error" do
        expect(
          middleware.call(
            message,
            proc { :success }
          )
        ).to eq(:reject)
      end
    end

    it "does not catch an error down the line" do
      expect {
        middleware.call(message, proc { raise })
      }.to raise_error(RuntimeError)
    end

    context "when encountering an error" do
      let(:payload) { "This is not JSON" }

      it "returns the result of the error handler" do
        expect(
          middleware.call(
            message,
            proc { :success }
          )
        ).to eq(:error_handler_result)
      end

      it "calls the error handler with the error" do
        expect(error_handler).to receive(:call).with(
          instance_of(MultiJson::ParseError)
        )

        middleware.call(message, proc { :success })
      end
    end
  end
end
