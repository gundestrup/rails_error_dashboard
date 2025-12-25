# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Queries::FilterOptions do
  describe ".call" do
    let!(:error1) { create(:error_log, error_type: "NoMethodError", platform: "iOS") }
    let!(:error2) { create(:error_log, error_type: "ArgumentError", platform: "Android") }
    let!(:error3) { create(:error_log, error_type: "TypeError", platform: "API") }
    let!(:error4) { create(:error_log, error_type: "NoMethodError", platform: "iOS") }

    it "returns hash with filter options" do
      result = described_class.call

      expect(result).to be_a(Hash)
      expect(result.keys).to include(:error_types, :platforms)
    end

    describe "error_types" do
      it "returns distinct error types" do
        result = described_class.call

        expect(result[:error_types]).to be_an(Array)
        expect(result[:error_types]).to include("NoMethodError", "ArgumentError", "TypeError")
      end

      it "sorts error types alphabetically" do
        result = described_class.call

        expect(result[:error_types]).to eq(result[:error_types].sort)
      end

      it "does not include duplicates" do
        create(:error_log, error_type: "NoMethodError")

        result = described_class.call

        expect(result[:error_types].count("NoMethodError")).to eq(1)
      end
    end

    describe "platforms" do
      it "returns distinct platforms" do
        result = described_class.call

        expect(result[:platforms]).to be_an(Array)
        expect(result[:platforms]).to include("iOS", "Android", "API")
      end

      it "does not include duplicates" do
        create(:error_log, platform: "iOS")

        result = described_class.call

        expect(result[:platforms].count("iOS")).to eq(1)
      end

      it "excludes nil values" do
        create(:error_log, platform: nil)

        result = described_class.call

        expect(result[:platforms]).not_to include(nil)
      end
    end

    context "with no errors" do
      before do
        RailsErrorDashboard::ErrorLog.destroy_all
      end

      it "returns empty arrays" do
        result = described_class.call

        expect(result[:error_types]).to eq([])
        expect(result[:platforms]).to eq([])
      end
    end

    context "with single error" do
      before do
        RailsErrorDashboard::ErrorLog.destroy_all
        create(:error_log, error_type: "StandardError", platform: "Web")
      end

      it "returns single values" do
        result = described_class.call

        expect(result[:error_types]).to eq([ "StandardError" ])
        expect(result[:platforms]).to eq([ "Web" ])
      end
    end
  end
end
