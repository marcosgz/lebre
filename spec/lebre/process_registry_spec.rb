# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lebre::ProcessRegistry do
  after do
    Lebre::ProcessRegistry.instance.clear
  end

  let(:supervisor) { instance_double(Lebre::Process, id: "p1") }
  let(:process) { instance_double(Lebre::Process, id: "p2", supervisor_id: "p1") }

  describe "#add" do
    it "adds a process to the registry" do
      Lebre::ProcessRegistry.instance.add(supervisor)

      expect(Lebre::ProcessRegistry.instance.instance_variable_get(:@processes)).to eq("p1" => supervisor)
    end
  end

  describe "#delete" do
    it "deletes a process from the registry" do
      Lebre::ProcessRegistry.instance.add(supervisor)
      Lebre::ProcessRegistry.instance.add(process)

      Lebre::ProcessRegistry.instance.delete(process)

      expect(Lebre::ProcessRegistry.instance.all).to eq([supervisor])
    end
  end

  describe "#find" do
    it "returns a process by id" do
      Lebre::ProcessRegistry.instance.add(supervisor)

      expect(Lebre::ProcessRegistry.instance.find("p1")).to eq(supervisor)
    end

    it "raises an error when the process does not exist" do
      expect do
        Lebre::ProcessRegistry.instance.find("non-existing")
      end.to raise_error(Lebre::Process::NotFoundError)
    end
  end

  describe "#exists?" do
    it "returns true when a process exists" do
      Lebre::ProcessRegistry.instance.add(supervisor)

      expect(Lebre::ProcessRegistry.instance.exists?("p1")).to be(true)
    end

    it "returns false when a process does not exist" do
      expect(Lebre::ProcessRegistry.instance.exists?("non-existing")).to be(false)
    end
  end

  describe "#all" do
    it "returns all processes" do
      Lebre::ProcessRegistry.instance.add(supervisor)
      Lebre::ProcessRegistry.instance.add(process)

      expect(Lebre::ProcessRegistry.instance.all).to eq([supervisor, process])
    end
  end

  describe "#clear" do
    it "clears all processes" do
      Lebre::ProcessRegistry.instance.add(supervisor)
      Lebre::ProcessRegistry.instance.add(process)

      Lebre::ProcessRegistry.instance.clear

      expect(Lebre::ProcessRegistry.instance.all).to eq([])
    end
  end
end
