# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Multi-App Context Filtering", type: :feature do
  let!(:app_a) { create(:application, name: "App A") }
  let!(:app_b) { create(:application, name: "App B") }

  let!(:error_app_a_1) { create(:error_log, application: app_a, error_type: "TypeError", platform: "iOS", occurred_at: 1.day.ago) }
  let!(:error_app_a_2) { create(:error_log, application: app_a, error_type: "NoMethodError", platform: "Android", occurred_at: 2.days.ago) }
  let!(:error_app_a_3) { create(:error_log, application: app_a, error_type: "TypeError", platform: "Web", occurred_at: 3.days.ago, resolved: true, resolved_at: 2.days.ago) }

  let!(:error_app_b_1) { create(:error_log, application: app_b, error_type: "RuntimeError", platform: "Web", occurred_at: 1.day.ago) }
  let!(:error_app_b_2) { create(:error_log, application: app_b, error_type: "ArgumentError", platform: "API", occurred_at: 2.days.ago) }

  describe "Query objects respect application_id filter" do
    describe "DashboardStats" do
      it "returns stats for all apps when application_id is nil" do
        result = RailsErrorDashboard::Queries::DashboardStats.call(application_id: nil)

        expect(result[:total_week]).to eq(5)
        expect(result[:total_month]).to eq(5)
      end

      it "returns stats only for App A when application_id is provided" do
        result = RailsErrorDashboard::Queries::DashboardStats.call(application_id: app_a.id)

        expect(result[:total_week]).to eq(3)
        expect(result[:total_month]).to eq(3)
        expect(result[:unresolved]).to eq(2)
        expect(result[:resolved]).to eq(1)
      end

      it "returns stats only for App B when application_id is provided" do
        result = RailsErrorDashboard::Queries::DashboardStats.call(application_id: app_b.id)

        expect(result[:total_week]).to eq(2)
        expect(result[:total_month]).to eq(2)
        expect(result[:unresolved]).to eq(2)
        expect(result[:resolved]).to eq(0)
      end

      it "filters top_errors by application" do
        result_a = RailsErrorDashboard::Queries::DashboardStats.call(application_id: app_a.id)
        result_b = RailsErrorDashboard::Queries::DashboardStats.call(application_id: app_b.id)

        expect(result_a[:top_errors].keys).to include("TypeError", "NoMethodError")
        expect(result_a[:top_errors].keys).not_to include("RuntimeError", "ArgumentError")

        expect(result_b[:top_errors].keys).to include("RuntimeError", "ArgumentError")
        expect(result_b[:top_errors].keys).not_to include("TypeError", "NoMethodError")
      end

      it "filters by_platform by application" do
        result_a = RailsErrorDashboard::Queries::DashboardStats.call(application_id: app_a.id)
        result_b = RailsErrorDashboard::Queries::DashboardStats.call(application_id: app_b.id)

        expect(result_a[:by_platform].keys).to match_array([ "iOS", "Android", "Web" ])
        expect(result_b[:by_platform].keys).to match_array([ "Web", "API" ])
      end
    end

    describe "PlatformComparison" do
      it "returns data for all apps when application_id is nil" do
        comparison = RailsErrorDashboard::Queries::PlatformComparison.new(days: 7, application_id: nil)
        error_rates = comparison.error_rate_by_platform

        expect(error_rates.values.sum).to eq(5)
      end

      it "returns data only for App A when application_id is provided" do
        comparison = RailsErrorDashboard::Queries::PlatformComparison.new(days: 7, application_id: app_a.id)
        error_rates = comparison.error_rate_by_platform

        expect(error_rates.values.sum).to eq(3)
        expect(error_rates.keys).to match_array([ "iOS", "Android", "Web" ])
      end

      it "returns data only for App B when application_id is provided" do
        comparison = RailsErrorDashboard::Queries::PlatformComparison.new(days: 7, application_id: app_b.id)
        error_rates = comparison.error_rate_by_platform

        expect(error_rates.values.sum).to eq(2)
        expect(error_rates.keys).to match_array([ "Web", "API" ])
      end
    end

    describe "ErrorCorrelation" do
      let!(:error_app_a_v1) { create(:error_log, application: app_a, app_version: "v1.0.0", occurred_at: 1.day.ago) }
      let!(:error_app_b_v1) { create(:error_log, application: app_b, app_version: "v1.0.0", occurred_at: 1.day.ago) }
      let!(:error_app_b_v2) { create(:error_log, application: app_b, app_version: "v2.0.0", occurred_at: 1.day.ago) }

      it "returns correlation for all apps when application_id is nil" do
        correlation = RailsErrorDashboard::Queries::ErrorCorrelation.new(days: 30, application_id: nil)
        errors_by_version = correlation.errors_by_version

        expect(errors_by_version.keys).to include("v1.0.0")
        expect(errors_by_version["v1.0.0"][:count]).to be >= 2
      end

      it "returns correlation only for App A when application_id is provided" do
        correlation = RailsErrorDashboard::Queries::ErrorCorrelation.new(days: 30, application_id: app_a.id)
        errors_by_version = correlation.errors_by_version

        expect(errors_by_version.keys).to include("v1.0.0")
        expect(errors_by_version.keys).not_to include("v2.0.0")
      end

      it "returns correlation only for App B when application_id is provided" do
        correlation = RailsErrorDashboard::Queries::ErrorCorrelation.new(days: 30, application_id: app_b.id)
        errors_by_version = correlation.errors_by_version

        expect(errors_by_version.keys).to include("v1.0.0", "v2.0.0")
      end
    end

    describe "RecurringIssues" do
      let!(:recurring_app_a) { create(:error_log, application: app_a, error_type: "RecurringError", occurrence_count: 15, occurred_at: 1.day.ago) }
      let!(:recurring_app_b) { create(:error_log, application: app_b, error_type: "AnotherRecurringError", occurrence_count: 20, occurred_at: 1.day.ago) }

      it "returns recurring issues for all apps when application_id is nil" do
        result = RailsErrorDashboard::Queries::RecurringIssues.call(30, application_id: nil)

        expect(result[:high_frequency_errors].length).to be >= 2
        error_types = result[:high_frequency_errors].map { |e| e[:error_type] }
        expect(error_types).to include("RecurringError", "AnotherRecurringError")
      end

      it "returns recurring issues only for App A when application_id is provided" do
        result = RailsErrorDashboard::Queries::RecurringIssues.call(30, application_id: app_a.id)

        error_types = result[:high_frequency_errors].map { |e| e[:error_type] }
        expect(error_types).to include("RecurringError")
        expect(error_types).not_to include("AnotherRecurringError")
      end

      it "returns recurring issues only for App B when application_id is provided" do
        result = RailsErrorDashboard::Queries::RecurringIssues.call(30, application_id: app_b.id)

        error_types = result[:high_frequency_errors].map { |e| e[:error_type] }
        expect(error_types).to include("AnotherRecurringError")
        expect(error_types).not_to include("RecurringError")
      end
    end

    describe "MttrStats" do
      let!(:resolved_app_a) do
        create(:error_log,
          application: app_a,
          occurred_at: 2.days.ago,
          resolved_at: 1.day.ago,
          platform: "iOS"
        )
      end
      let!(:resolved_app_b) do
        create(:error_log,
          application: app_b,
          occurred_at: 3.days.ago,
          resolved_at: 1.day.ago,
          platform: "Android"
        )
      end

      it "returns MTTR stats for all apps when application_id is nil" do
        result = RailsErrorDashboard::Queries::MttrStats.call(30, application_id: nil)

        expect(result[:total_resolved]).to eq(3) # Including the one created in let! earlier
      end

      it "returns MTTR stats only for App A when application_id is provided" do
        result = RailsErrorDashboard::Queries::MttrStats.call(30, application_id: app_a.id)

        expect(result[:total_resolved]).to eq(2) # resolved_app_a + error_app_a_3
        expect(result[:mttr_by_platform].keys).to include("iOS", "Web")
        expect(result[:mttr_by_platform].keys).not_to include("Android")
      end

      it "returns MTTR stats only for App B when application_id is provided" do
        result = RailsErrorDashboard::Queries::MttrStats.call(30, application_id: app_b.id)

        expect(result[:total_resolved]).to eq(1) # resolved_app_b
        expect(result[:mttr_by_platform].keys).to include("Android")
        expect(result[:mttr_by_platform].keys).not_to include("iOS")
      end
    end

    describe "FilterOptions" do
      it "returns all error types when application_id is nil" do
        result = RailsErrorDashboard::Queries::FilterOptions.call(application_id: nil)

        expect(result[:error_types]).to include("TypeError", "NoMethodError", "RuntimeError", "ArgumentError")
        expect(result[:platforms]).to include("iOS", "Android", "Web", "API")
      end

      it "returns error types only for App A when application_id is provided" do
        result = RailsErrorDashboard::Queries::FilterOptions.call(application_id: app_a.id)

        expect(result[:error_types]).to include("TypeError", "NoMethodError")
        expect(result[:error_types]).not_to include("RuntimeError", "ArgumentError")
      end

      it "returns platforms only for App A when application_id is provided" do
        result = RailsErrorDashboard::Queries::FilterOptions.call(application_id: app_a.id)

        expect(result[:platforms]).to include("iOS", "Android", "Web")
        expect(result[:platforms]).not_to include("API")
      end

      it "returns error types only for App B when application_id is provided" do
        result = RailsErrorDashboard::Queries::FilterOptions.call(application_id: app_b.id)

        expect(result[:error_types]).to include("RuntimeError", "ArgumentError")
        expect(result[:error_types]).not_to include("TypeError", "NoMethodError")
      end

      it "returns platforms only for App B when application_id is provided" do
        result = RailsErrorDashboard::Queries::FilterOptions.call(application_id: app_b.id)

        expect(result[:platforms]).to include("Web", "API")
        expect(result[:platforms]).not_to include("iOS", "Android")
      end
    end
  end

  describe "ErrorLog#related_errors" do
    let!(:error_app_a_same_type) { create(:error_log, application: app_a, error_type: "TypeError", occurred_at: 1.hour.ago) }
    let!(:error_app_b_same_type) { create(:error_log, application: app_b, error_type: "TypeError", occurred_at: 1.hour.ago) }

    it "returns all related errors when application_id is nil" do
      related = error_app_a_1.related_errors(limit: 10, application_id: nil)

      expect(related.length).to be >= 2
      expect(related.map(&:id)).to include(error_app_a_3.id, error_app_a_same_type.id, error_app_b_same_type.id)
    end

    it "returns only App A related errors when application_id is provided" do
      related = error_app_a_1.related_errors(limit: 10, application_id: app_a.id)

      expect(related.map(&:id)).to include(error_app_a_3.id, error_app_a_same_type.id)
      expect(related.map(&:id)).not_to include(error_app_b_same_type.id)
    end

    it "returns only App B related errors when application_id is provided" do
      related = error_app_b_same_type.related_errors(limit: 10, application_id: app_b.id)

      # Should not include any App A errors with same type
      app_a_error_ids = [ error_app_a_1.id, error_app_a_3.id, error_app_a_same_type.id ]
      expect(related.map(&:id) & app_a_error_ids).to be_empty
    end
  end

  describe "Backward compatibility" do
    it "works with single app without application_id parameter" do
      # Simulate single-app installation
      RailsErrorDashboard::Application.where.not(id: app_a.id).destroy_all
      RailsErrorDashboard::ErrorLog.where.not(application_id: app_a.id).destroy_all

      result = RailsErrorDashboard::Queries::DashboardStats.call

      expect(result[:total_week]).to be >= 1
      expect(result).to have_key(:total_today)
      expect(result).to have_key(:unresolved)
    end
  end
end
