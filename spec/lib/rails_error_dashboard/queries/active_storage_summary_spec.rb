# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Queries::ActiveStorageSummary do
  def breadcrumbs_json(*crumbs)
    crumbs.to_json
  end

  def storage_crumb(service:, operation: "upload", key: "abc123", duration: nil)
    crumb = {
      "c" => "active_storage",
      "m" => "#{operation} #{key} (#{service})",
      "meta" => {
        "service" => service,
        "operation" => operation,
        "key" => key
      }
    }
    crumb["d"] = duration if duration
    crumb
  end

  def sql_crumb(message)
    { "c" => "sql", "m" => message, "d" => 1.2 }
  end

  describe ".call" do
    it "returns empty services when no errors exist" do
      result = described_class.call(30)
      expect(result[:services]).to eq([])
    end

    it "returns empty services when errors have no breadcrumbs" do
      create(:error_log, breadcrumbs: nil, occurred_at: 1.day.ago)
      result = described_class.call(30)
      expect(result[:services]).to eq([])
    end

    it "returns empty services when no active_storage breadcrumbs exist" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(sql_crumb("SELECT 1")),
        occurred_at: 1.day.ago)

      result = described_class.call(30)
      expect(result[:services]).to eq([])
    end

    it "groups storage operations by service name" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(
          storage_crumb(service: "Disk", operation: "upload"),
          storage_crumb(service: "S3", operation: "download"),
          storage_crumb(service: "Disk", operation: "delete")
        ),
        occurred_at: 1.day.ago)

      result = described_class.call(30)
      expect(result[:services].size).to eq(2)

      disk = result[:services].find { |s| s[:service] == "Disk" }
      s3 = result[:services].find { |s| s[:service] == "S3" }

      expect(disk[:upload_count]).to eq(1)
      expect(disk[:delete_count]).to eq(1)
      expect(disk[:total_operations]).to eq(2)

      expect(s3[:download_count]).to eq(1)
      expect(s3[:total_operations]).to eq(1)
    end

    it "counts each operation type correctly" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(
          storage_crumb(service: "S3", operation: "upload"),
          storage_crumb(service: "S3", operation: "upload"),
          storage_crumb(service: "S3", operation: "download"),
          storage_crumb(service: "S3", operation: "delete"),
          storage_crumb(service: "S3", operation: "delete_prefixed"),
          storage_crumb(service: "S3", operation: "exist"),
          storage_crumb(service: "S3", operation: "streaming_download")
        ),
        occurred_at: 1.day.ago)

      result = described_class.call(30)
      s3 = result[:services].first

      expect(s3[:upload_count]).to eq(2)
      expect(s3[:download_count]).to eq(2)  # download + streaming_download
      expect(s3[:delete_count]).to eq(2)    # delete + delete_prefixed
      expect(s3[:exist_count]).to eq(1)
      expect(s3[:total_operations]).to eq(7)
    end

    it "computes avg and slowest duration" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(
          storage_crumb(service: "S3", operation: "upload", duration: 10.5),
          storage_crumb(service: "S3", operation: "upload", duration: 20.5),
          storage_crumb(service: "S3", operation: "download", duration: 5.0)
        ),
        occurred_at: 1.day.ago)

      result = described_class.call(30)
      s3 = result[:services].first

      expect(s3[:avg_duration_ms]).to eq(12.0)
      expect(s3[:slowest_ms]).to eq(20.5)
    end

    it "respects time range" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(storage_crumb(service: "Disk")),
        occurred_at: 5.days.ago)

      create(:error_log,
        breadcrumbs: breadcrumbs_json(storage_crumb(service: "Disk")),
        occurred_at: 60.days.ago)

      result = described_class.call(7)
      expect(result[:services].first[:error_count]).to eq(1)
    end

    it "filters by application_id" do
      app1 = create(:application, name: "App1")
      app2 = create(:application, name: "App2")

      create(:error_log,
        breadcrumbs: breadcrumbs_json(storage_crumb(service: "S3")),
        application: app1, occurred_at: 1.day.ago)

      create(:error_log,
        breadcrumbs: breadcrumbs_json(storage_crumb(service: "S3")),
        application: app2, occurred_at: 1.day.ago)

      result = described_class.call(30, application_id: app1.id)
      expect(result[:services].first[:error_count]).to eq(1)
    end

    it "sorts by total operations descending" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(
          storage_crumb(service: "Disk", operation: "upload")
        ),
        occurred_at: 1.day.ago)

      create(:error_log,
        breadcrumbs: breadcrumbs_json(
          storage_crumb(service: "S3", operation: "upload"),
          storage_crumb(service: "S3", operation: "download"),
          storage_crumb(service: "S3", operation: "delete")
        ),
        occurred_at: 1.day.ago)

      result = described_class.call(30)
      expect(result[:services].first[:service]).to eq("S3")
      expect(result[:services].last[:service]).to eq("Disk")
    end

    it "handles malformed breadcrumbs JSON gracefully" do
      create(:error_log, breadcrumbs: "not json{", occurred_at: 1.day.ago)
      result = described_class.call(30)
      expect(result[:services]).to eq([])
    end

    it "tracks unique error count per service" do
      create(:error_log,
        breadcrumbs: breadcrumbs_json(
          storage_crumb(service: "S3"),
          storage_crumb(service: "S3")
        ),
        occurred_at: 1.day.ago)

      result = described_class.call(30)
      expect(result[:services].first[:error_count]).to eq(1)
    end
  end
end
