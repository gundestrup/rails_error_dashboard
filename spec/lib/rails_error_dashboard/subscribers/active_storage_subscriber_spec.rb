# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Subscribers::ActiveStorageSubscriber do
  let(:collector) { RailsErrorDashboard::Services::BreadcrumbCollector }

  before do
    RailsErrorDashboard.configuration.enable_breadcrumbs = true
    collector.init_buffer
  end

  after do
    described_class.unsubscribe!
    collector.clear_buffer
    RailsErrorDashboard.reset_configuration!
  end

  describe ".subscribe!" do
    it "registers all expected event subscribers" do
      subscriptions = described_class.subscribe!
      expect(subscriptions).to be_an(Array)
      expect(subscriptions.size).to eq(6)
    end

    it "stores subscriptions for later cleanup" do
      described_class.subscribe!
      expect(described_class.subscriptions).not_to be_empty
    end
  end

  describe ".unsubscribe!" do
    it "removes all subscriptions" do
      described_class.subscribe!
      expect(described_class.subscriptions).not_to be_empty

      described_class.unsubscribe!
      expect(described_class.subscriptions).to be_empty
    end
  end

  describe "service_upload.active_storage subscriber" do
    before { described_class.subscribe! }

    it "adds active_storage breadcrumb with upload details" do
      ActiveSupport::Notifications.instrument("service_upload.active_storage", {
        key: "abc123def456",
        checksum: "xxhash",
        service: "Disk"
      }) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty

      crumb = as_crumbs.last
      expect(crumb[:m]).to include("upload")
      expect(crumb[:m]).to include("Disk")
      expect(crumb[:meta][:service]).to eq("Disk")
      expect(crumb[:meta][:operation]).to eq("upload")
      expect(crumb[:meta][:key]).to eq("abc123def456")
    end
  end

  describe "service_download.active_storage subscriber" do
    before { described_class.subscribe! }

    it "adds active_storage breadcrumb with download details" do
      ActiveSupport::Notifications.instrument("service_download.active_storage", {
        key: "file-key-789",
        service: "S3"
      }) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty

      crumb = as_crumbs.last
      expect(crumb[:m]).to include("download")
      expect(crumb[:m]).to include("S3")
      expect(crumb[:meta][:service]).to eq("S3")
      expect(crumb[:meta][:operation]).to eq("download")
    end
  end

  describe "service_delete.active_storage subscriber" do
    before { described_class.subscribe! }

    it "adds active_storage breadcrumb with delete details" do
      ActiveSupport::Notifications.instrument("service_delete.active_storage", {
        key: "old-file-key",
        service: "GCS"
      }) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty

      crumb = as_crumbs.last
      expect(crumb[:m]).to include("delete")
      expect(crumb[:m]).to include("GCS")
      expect(crumb[:meta][:operation]).to eq("delete")
    end
  end

  describe "service_exist.active_storage subscriber" do
    before { described_class.subscribe! }

    it "adds active_storage breadcrumb with exist check details" do
      ActiveSupport::Notifications.instrument("service_exist.active_storage", {
        key: "check-key",
        exist: true,
        service: "Disk"
      }) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty

      crumb = as_crumbs.last
      expect(crumb[:m]).to include("exist?")
      expect(crumb[:meta][:operation]).to eq("exist")
    end
  end

  describe "service_delete_prefixed.active_storage subscriber" do
    before { described_class.subscribe! }

    it "adds active_storage breadcrumb with prefix details" do
      ActiveSupport::Notifications.instrument("service_delete_prefixed.active_storage", {
        prefix: "variants/abc",
        service: "Disk"
      }) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty

      crumb = as_crumbs.last
      expect(crumb[:m]).to include("delete_prefixed")
      expect(crumb[:meta][:operation]).to eq("delete_prefixed")
      expect(crumb[:meta][:key]).to eq("variants/abc")
    end
  end

  describe "duration capture" do
    before { described_class.subscribe! }

    it "captures duration for upload events" do
      ActiveSupport::Notifications.instrument("service_upload.active_storage", {
        key: "timed-upload",
        service: "S3"
      }) { sleep 0.001 }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs.last[:d]).to be_a(Numeric)
      expect(as_crumbs.last[:d]).to be >= 0
    end
  end

  describe "safety" do
    before { described_class.subscribe! }

    it "skips when no breadcrumb buffer is active" do
      collector.clear_buffer

      ActiveSupport::Notifications.instrument("service_upload.active_storage", {
        key: "orphan-upload",
        service: "Disk"
      }) { }

      collector.init_buffer
      breadcrumbs = collector.harvest
      expect(breadcrumbs.select { |c| c[:c] == "active_storage" }).to be_empty
    end

    it "handles empty payload gracefully" do
      ActiveSupport::Notifications.instrument("service_upload.active_storage", {}) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty
      expect(as_crumbs.last[:meta][:service]).to eq("Unknown")
    end

    it "handles nil payload values gracefully" do
      ActiveSupport::Notifications.instrument("service_download.active_storage", {
        key: nil,
        service: nil
      }) { }

      breadcrumbs = collector.harvest
      as_crumbs = breadcrumbs.select { |c| c[:c] == "active_storage" }
      expect(as_crumbs).not_to be_empty
      expect(as_crumbs.last[:m]).to include("Unknown")
    end
  end
end
