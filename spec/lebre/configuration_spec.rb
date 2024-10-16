# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lebre::Configuration do
  let(:configuration) { described_class.new }

  it "has a default rabbitmq url" do
    stub_const("ENV", ENV.to_hash.merge("RABBITMQ_URL" => nil))
    expect(configuration.rabbitmq_url).to eq(
      "amqp://guest:guest@localhost:5672"
    )
  end

  it "allows setting the rabbitmq url" do
    configuration.rabbitmq_url = "test"

    expect(configuration.rabbitmq_url).to eq("test")
  end

  it "allows setting the connection name" do
    configuration.connection_name = "conn"

    expect(configuration.connection_name).to eq("conn")
  end

  it "allows setting the recover_from_connection_close" do
    configuration.recover_from_connection_close = false

    expect(configuration.recover_from_connection_close).to be(false)
  end

  it "allows setting the recovery_attempts" do
    configuration.recovery_attempts = 2

    expect(configuration.recovery_attempts).to eq(2)
  end

  it "has a default recovery_attempt" do
    expect(configuration.recovery_attempts).to eq(10)
  end

  context "when recovery attempts are set" do
    before { configuration.recovery_attempts = 2 }

    it "sets recovery_attempts_exhausted to a raising proc" do
      proc = configuration.send(:recovery_attempts_exhausted)

      expect { proc.call }.to raise_error(
        Lebre::MaxRecoveryAttemptsExhaustedError
      )
    end
  end

  context "when recovery attempts are set to nil" do
    before { configuration.recovery_attempts = nil }

    it "sets also recovery_attempts_exhausted to nil" do
      expect(configuration.recovery_attempts).to be_nil
    end
  end

  describe "#consumers_directory" do
    it "defaults to the app/consumers" do
      expect(configuration.consumers_directory).to eq(Pathname.new("app/consumers"))
    end

    it "wraps the string path to an instance of Pathname" do
      configuration.consumers_directory = "lib/consumers"
      expect(configuration.consumers_directory).to eq(Pathname.new("lib/consumers"))
    end
  end
end
