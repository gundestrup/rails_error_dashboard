# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Services::CacheAnalyzer do
  describe ".call" do
    it "returns nil for nil input" do
      expect(described_class.call(nil)).to be_nil
    end

    it "returns nil for empty array" do
      expect(described_class.call([])).to be_nil
    end

    it "returns nil when no cache breadcrumbs exist" do
      breadcrumbs = [
        { "c" => "sql", "m" => "SELECT 1", "d" => 1.0 }
      ]
      expect(described_class.call(breadcrumbs)).to be_nil
    end

    it "counts reads and writes" do
      breadcrumbs = [
        { "c" => "cache", "m" => "cache read: users/1", "d" => 1.0, "meta" => { "hit" => true } },
        { "c" => "cache", "m" => "cache read: users/2", "d" => 2.0, "meta" => { "hit" => false } },
        { "c" => "cache", "m" => "cache write: users/3", "d" => 0.5 }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:reads]).to eq(2)
      expect(result[:writes]).to eq(1)
    end

    it "calculates hit rate from known hits and misses" do
      breadcrumbs = [
        { "c" => "cache", "m" => "cache read: a", "d" => 1.0, "meta" => { "hit" => true } },
        { "c" => "cache", "m" => "cache read: b", "d" => 1.0, "meta" => { "hit" => true } },
        { "c" => "cache", "m" => "cache read: c", "d" => 1.0, "meta" => { "hit" => false } }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:hits]).to eq(2)
      expect(result[:misses]).to eq(1)
      expect(result[:hit_rate]).to eq(66.7)
    end

    it "returns nil hit_rate when all reads have unknown hit status" do
      breadcrumbs = [
        { "c" => "cache", "m" => "cache read: a", "d" => 1.0 },
        { "c" => "cache", "m" => "cache read: b", "d" => 2.0 }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:reads]).to eq(2)
      expect(result[:unknown]).to eq(2)
      expect(result[:hit_rate]).to be_nil
    end

    it "finds the slowest operation" do
      breadcrumbs = [
        { "c" => "cache", "m" => "cache read: fast", "d" => 0.5, "meta" => { "hit" => true } },
        { "c" => "cache", "m" => "cache read: slow", "d" => 15.0, "meta" => { "hit" => false } },
        { "c" => "cache", "m" => "cache write: medium", "d" => 3.0 }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:slowest][:message]).to eq("cache read: slow")
      expect(result[:slowest][:duration_ms]).to eq(15.0)
    end

    it "calculates total duration" do
      breadcrumbs = [
        { "c" => "cache", "m" => "cache read: a", "d" => 1.5, "meta" => { "hit" => true } },
        { "c" => "cache", "m" => "cache write: b", "d" => 2.5 }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:total_duration_ms]).to eq(4.0)
    end

    it "ignores non-cache breadcrumbs" do
      breadcrumbs = [
        { "c" => "sql", "m" => "SELECT 1", "d" => 100.0 },
        { "c" => "cache", "m" => "cache read: x", "d" => 1.0, "meta" => { "hit" => true } },
        { "c" => "controller", "m" => "UsersController#show", "d" => 50.0 }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:reads]).to eq(1)
      expect(result[:writes]).to eq(0)
      expect(result[:total_duration_ms]).to eq(1.0)
    end

    it "handles string 'true'/'false' for hit status" do
      breadcrumbs = [
        { "c" => "cache", "m" => "cache read: a", "d" => 1.0, "meta" => { "hit" => "true" } },
        { "c" => "cache", "m" => "cache read: b", "d" => 1.0, "meta" => { "hit" => "false" } }
      ]
      result = described_class.call(breadcrumbs)

      expect(result[:hits]).to eq(1)
      expect(result[:misses]).to eq(1)
    end

    it "returns nil on bad input that raises" do
      expect(described_class.call("not an array")).to be_nil
    end
  end
end
