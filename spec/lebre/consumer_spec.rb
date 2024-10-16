# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lebre::Consumer do
  let(:channel) { instance_double(Bunny::Channel) }
  let(:queue) { instance_double(Bunny::Queue) }
  let(:instance) { Class.new(described_class).new }
  let(:delivery_info) do
    instance_double(Bunny::DeliveryInfo, delivery_tag: delivery_tag)
  end
  let(:delivery_tag) { 1 }
  let(:metadata) { instance_double(Bunny::MessageProperties) }
  let(:payload) { "my payload" }
  let(:message) do
    Lebre::Message.new(delivery_info, metadata, payload)
  end

  before do
    allow(channel).to receive_messages(generate_consumer_tag: "test", number: 1)
    allow(channel).to receive(:ack).with(delivery_tag, false)
  end

  describe ".descendants" do
    specify do
      expect(described_class.descendants).to be_a(Array)
    end
  end

  describe ".abstract_class?" do
    it "returns true when is not configured" do
      expect(described_class.abstract_class?).to be true
    end

    it "returns false when configured" do
      instance.class.configure(queue: "test")
      expect(instance.class.abstract_class?).to be false
    end

    context "when abstract class is set" do
      let(:abstract_class) do
        Class.new(described_class) do
          self.abstract_class = true
        end
      end

      it "returns true" do
        expect(abstract_class.abstract_class?).to be true
        expect(abstract_class.config).to be_nil
      end
    end
  end

  describe ".configure" do
    let(:mandatory_options) do
      {queue: "test", exchange: "exchange", routing_key: ["test.new"]}
    end
    let(:custom_consumer_class) { Class.new(described_class) }

    it "sets the config" do
      custom_consumer_class.configure(mandatory_options)

      expect(custom_consumer_class.config).to be_a(Lebre::ConsumerConfig)
      expect(custom_consumer_class.config.consumer_queue_args).to eq(["test", {durable: true}])
      expect(custom_consumer_class.config.exchange_args).to eq(["exchange", {durable: true, type: :topic}])
      expect(custom_consumer_class.config.binds_args).to eq([{routing_key: "test.new"}])
    end
  end

  describe "#perform" do
    it "raises a not implemented error" do
      expect { instance.perform(message) }.to raise_error(
        NotImplementedError
      )
    end
  end

  describe "#process_delivery" do
    it "calls #perform" do
      expect(instance).to receive(:perform).with(
        message
      ).and_return(:ack)

      instance.process_delivery(delivery_info, metadata, payload)
    end

    it "returns the result of #perform" do
      allow(instance).to receive(:perform).and_return(:ack)

      expect(instance.process_delivery(delivery_info, metadata, payload)).to eq(
        :ack
      )
    end

    it "allows returning :ack" do
      allow(instance).to receive(:perform).and_return(:ack)

      expect(
        instance.process_delivery(delivery_info, metadata, payload)
      ).to be :ack
    end

    it "allows returning :reject" do
      allow(instance).to receive(:perform).and_return(:reject)

      expect(
        instance.process_delivery(delivery_info, metadata, payload)
      ).to be :reject
    end

    it "allows returning :requeue" do
      allow(instance).to receive(:perform).and_return(:requeue)

      expect(
        instance.process_delivery(delivery_info, metadata, payload)
      ).to be :requeue
    end

    it "raises an error if #perform does not return a valid symbol" do
      allow(instance).to receive(:perform).and_return(:blorg)

      expect {
        instance.process_delivery(delivery_info, metadata, payload)
      }.to raise_error(
        Lebre::InvalidConsumerReturnError,
        "#perform must return :ack, :reject or :requeue, received :blorg instead"
      )
    end
  end

  describe "#ack" do
    let(:instance) do
      Class.new(Lebre::Consumer) do
        def perform(_message)
          ack
        end
      end.new
    end

    it "returns :ack when called in #message" do
      expect(instance.perform(message)).to eq(:ack)
    end
  end

  describe "#reject" do
    let(:instance) do
      Class.new(Lebre::Consumer) do
        def perform(_message)
          reject
        end
      end.new
    end

    it "returns :reject when called in #perform" do
      expect(instance.perform(message)).to eq(:reject)
    end
  end

  describe "#requeue" do
    let(:instance) do
      Class.new(Lebre::Consumer) do
        def perform(_message)
          requeue
        end
      end.new
    end

    it "returns :requeue when called in #perform" do
      expect(instance.perform(message)).to eq(:requeue)
    end
  end

  describe ".use" do
    let(:instance) do
      Class.new(Lebre::Consumer) do
        use Middleware

        def perform(_message)
          ack
        end
      end.new
    end

    let(:instance_with_two_middlewares) do
      Class.new(Lebre::Consumer) do
        use Middleware
        use SecondMiddleware

        def perform(_message)
          ack
        end
      end.new
    end

    let(:middleware) { stub_const("Middleware", Class.new) }
    let(:middleware_instance) { instance_double(Middleware) }
    let(:second_middleware) { stub_const("SecondMiddleware", Class.new) }
    let(:second_middleware_instance) { instance_double(SecondMiddleware) }

    it "wraps the given middleware around the call to perform" do
      expect(middleware).to receive(:new).and_return(middleware_instance)
      expect(middleware_instance).to receive(:call) do |msg, app|
        expect(message).to eq(msg)
        app.call(msg)
      end

      expect(instance.process_delivery(delivery_info, metadata, payload)).to eq(
        :ack
      )
    end

    it "calls middlewares in the correct order" do
      expect(middleware).to receive(:new).and_return(
        middleware_instance
      ).ordered
      expect(second_middleware).to receive(:new).and_return(
        second_middleware_instance
      ).ordered
      expect(middleware_instance).to receive(:call) do |m, app|
        app.call(m)
      end.ordered
      expect(second_middleware_instance).to receive(:call) do |m, app|
        app.call(m)
      end.ordered

      expect(
        instance_with_two_middlewares.process_delivery(
          delivery_info,
          metadata,
          payload
        )
      ).to eq(:ack)
    end
  end
end
