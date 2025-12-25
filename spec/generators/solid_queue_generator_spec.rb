# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Solid Queue Generator Template", type: :generator do
  let(:template_path) do
    File.expand_path("../../lib/generators/rails_error_dashboard/solid_queue/templates/queue.yml", __dir__)
  end

  let(:config) { YAML.load_file(template_path) }

  it "template file exists" do
    expect(File.exist?(template_path)).to be true
  end

  it "generates valid YAML configuration" do
    expect(config).to be_a(Hash)
    expect(config.keys).to include("development", "test", "production", "staging")
  end

  describe "development configuration" do
    it "includes error_notifications queue" do
      workers = config["development"]["workers"]
      error_notifications_worker = workers.find { |w| w["queues"] == "error_notifications" }

      expect(error_notifications_worker).to be_present
      expect(error_notifications_worker["threads"]).to eq(2)
      expect(error_notifications_worker["processes"]).to eq(1)
      expect(error_notifications_worker["polling_interval"]).to eq(1)
    end

    it "includes default queue" do
      workers = config["development"]["workers"]
      default_worker = workers.find { |w| w["queues"] == "default" }

      expect(default_worker).to be_present
      expect(default_worker["threads"]).to eq(3)
      expect(default_worker["processes"]).to eq(1)
      expect(default_worker["polling_interval"]).to eq(1)
    end
  end

  describe "production configuration" do
    it "has higher thread count for default queue" do
      workers = config["production"]["workers"]
      default_worker = workers.find { |w| w["queues"] == "default" }

      expect(default_worker["threads"]).to eq(5)
      expect(default_worker["processes"]).to eq(2)
    end

    it "has optimized polling interval" do
      workers = config["production"]["workers"]
      workers.each do |worker|
        expect(worker["polling_interval"]).to eq(0.5)
      end
    end

    it "includes both queues" do
      workers = config["production"]["workers"]
      queue_names = workers.map { |w| w["queues"] }

      expect(queue_names).to include("error_notifications", "default")
    end
  end

  describe "test configuration" do
    it "uses wildcard queue to process all queues" do
      workers = config["test"]["workers"]
      expect(workers.first["queues"]).to eq("*")
    end

    it "has minimal threads and processes" do
      workers = config["test"]["workers"]
      expect(workers.first["threads"]).to eq(1)
      expect(workers.first["processes"]).to eq(1)
    end

    it "has fast polling interval for tests" do
      workers = config["test"]["workers"]
      expect(workers.first["polling_interval"]).to eq(0.1)
    end
  end

  describe "staging configuration" do
    it "includes both queues with moderate settings" do
      workers = config["staging"]["workers"]

      error_worker = workers.find { |w| w["queues"] == "error_notifications" }
      expect(error_worker["threads"]).to eq(2)
      expect(error_worker["processes"]).to eq(1)

      default_worker = workers.find { |w| w["queues"] == "default" }
      expect(default_worker["threads"]).to eq(3)
      expect(default_worker["processes"]).to eq(1)
    end

    it "has optimized polling for staging" do
      workers = config["staging"]["workers"]
      workers.each do |worker|
        expect(worker["polling_interval"]).to eq(0.5)
      end
    end
  end

  describe "all environments" do
    it "include workers configuration" do
      %w[development test production staging].each do |env|
        expect(config[env]).to have_key("workers")
        expect(config[env]["workers"]).to be_an(Array)
        expect(config[env]["workers"]).not_to be_empty
      end
    end

    it "have valid worker configurations" do
      %w[development test production staging].each do |env|
        config[env]["workers"].each do |worker|
          expect(worker).to have_key("queues")
          expect(worker).to have_key("threads")
          expect(worker).to have_key("processes")
          expect(worker).to have_key("polling_interval")

          expect(worker["threads"]).to be > 0
          expect(worker["processes"]).to be > 0
          expect(worker["polling_interval"]).to be >= 0
        end
      end
    end
  end
end
