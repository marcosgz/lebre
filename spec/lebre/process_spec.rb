# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lebre::Process do
  after do
    Lebre::ProcessRegistry.instance.clear
  end

  describe ".register" do
    it "creates a process and adds it to the registry" do
      process = described_class.register(name: "my-process")

      expect(process.id).to be_a(String)
      expect(Lebre::ProcessRegistry.instance.all).to eq([process])
    end
  end

  describe ".prune" do
    it "deletes all processes that are not running" do
      prune = described_class.register(last_heartbeat_at: Time.now - 5 * 60, name: "prune-me")
      keep = described_class.register(last_heartbeat_at: Time.now, name: "keep-me")

      described_class.prune

      expect(Lebre::ProcessRegistry.instance.all).to eq([keep])
    end
  end

  describe "#heartbeat" do
    it "updates the last_heartbeat_at" do
      process = described_class.register(name: "my-process")

      expect { process.heartbeat }.to change { Lebre::ProcessRegistry.instance.find(process.id).last_heartbeat_at }
    end
  end

  describe "#update_attributes" do
    it "updates the attributes" do
      process = described_class.register(name: "my-process")

      process.update_attributes(name: "new-name")

      expect(process.name).to eq("new-name")
    end
  end

  describe "#destroy!" do
    it "removes the process from the registry" do
      process = described_class.register(name: "my-process")

      process.destroy!

      expect(Lebre::ProcessRegistry.instance.all).to eq([])
    end
  end

  describe "#deregister" do
    it "removes the process from the registry and deregisters supervisees" do
      supervisor1 = described_class.register(name: "supervisor-1")
      supervisee1 = described_class.register(name: "supervisee-1", supervisor_id: supervisor1.id)

      supervisor2 = described_class.register(name: "supervisor-2")
      supervisee2 = described_class.register(name: "supervisee-2", supervisor_id: supervisor2.id)

      supervisor1.deregister

      expect(Lebre::ProcessRegistry.instance.all).to eq([supervisor2, supervisee2])
    end

    it "does not deregister supervisor" do
      supervisor = described_class.register(name: "supervisor")
      supervisee = described_class.register(name: "supervisee", supervisor_id: supervisor.id)

      supervisee.deregister

      expect(Lebre::ProcessRegistry.instance.all).to eq([supervisor])
    end
  end

  describe "#supervised?" do
    it "returns true if the process is supervised" do
      process = described_class.register(supervisor_id: "supervisor-id")

      expect(process).to be_supervised
    end

    it "returns false if the process is not supervised" do
      process = described_class.register

      expect(process).not_to be_supervised
    end
  end

  describe "#eql?" do
    it "returns true if the processes are equal" do
      process1 = described_class.register(id: "id", pid: "pid")
      process2 = described_class.register(id: "id", pid: "pid")

      expect(process1).to eq(process2)
    end

    it "returns false if the processes are not equal" do
      process1 = described_class.register(id: "id", pid: "pid")
      process2 = described_class.register(id: "id", pid: "other-pid")

      expect(process1).not_to eq(process2)
    end
  end
end
