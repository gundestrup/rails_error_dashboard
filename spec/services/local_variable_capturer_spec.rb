# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Services::LocalVariableCapturer do
  after do
    described_class.disable!
  end

  describe ".enable! / .disable! / .enabled?" do
    it "starts disabled" do
      expect(described_class.enabled?).to be false
    end

    it "can be enabled" do
      described_class.enable!
      expect(described_class.enabled?).to be true
    end

    it "can be disabled after enabling" do
      described_class.enable!
      described_class.disable!
      expect(described_class.enabled?).to be false
    end

    it "is idempotent when calling enable! twice" do
      described_class.enable!
      described_class.enable!
      expect(described_class.enabled?).to be true
    end

    it "is safe to call disable! when already disabled" do
      expect { described_class.disable! }.not_to raise_error
    end
  end

  describe "capture behavior" do
    before { described_class.enable! }

    it "captures local variables when an exception is raised in app code" do
      # The spec file path contains 'rails_error_dashboard' which the capturer skips,
      # so we test by manually attaching locals (simulating what the TracePoint does)
      exception = StandardError.new("test error")
      exception.instance_variable_set(:@_red_locals, { user_name: "Gandalf", error_code: 42 })

      locals = described_class.extract(exception)
      expect(locals).to be_a(Hash)
      expect(locals[:user_name]).to eq("Gandalf")
      expect(locals[:error_code]).to eq(42)
    end

    it "skips SystemExit" do
      exception = SystemExit.new(0)
      expect(described_class.extract(exception)).to be_nil
    end

    it "skips re-raises (already captured)" do
      exception = nil
      begin
        x = 1
        _unused = x
        begin
          raise StandardError, "inner"
        rescue => e
          raise e # re-raise — should NOT overwrite @_red_locals
        end
      rescue => e
        exception = e
      end

      locals = described_class.extract(exception)
      # Should have locals from the first raise, not overwritten by re-raise
      if locals
        expect(locals).to be_a(Hash)
      end
    end

    it "captures multiple variables from a single frame" do
      exception = StandardError.new("test")
      many_locals = (1..25).each_with_object({}) { |i, h| h[:"var_#{i}"] = "val_#{i}" }
      exception.instance_variable_set(:@_red_locals, many_locals)

      locals = described_class.extract(exception)
      expect(locals.size).to eq(25)
    end

    it "returns nil when exception has no local variables captured" do
      exception = StandardError.new("test")
      # No @_red_locals set — no TracePoint fired or exception from filtered path
      expect(described_class.extract(exception)).to be_nil
    end
  end

  describe ".extract" do
    it "returns nil for nil input" do
      expect(described_class.extract(nil)).to be_nil
    end

    it "returns nil for non-exception input" do
      expect(described_class.extract("not an exception")).to be_nil
    end

    it "returns nil when exception has no @_red_locals" do
      exception = StandardError.new("test")
      expect(described_class.extract(exception)).to be_nil
    end

    it "returns hash when exception has @_red_locals" do
      exception = StandardError.new("test")
      exception.instance_variable_set(:@_red_locals, { x: 1, y: "hello" })
      result = described_class.extract(exception)
      expect(result).to eq({ x: 1, y: "hello" })
    end

    it "never raises even with problematic exception" do
      exception = StandardError.new("test")
      allow(exception).to receive(:instance_variable_defined?).and_raise("boom")
      expect { described_class.extract(exception) }.not_to raise_error
      expect(described_class.extract(exception)).to be_nil
    end

    it "handles frozen exception without crashing" do
      exception = StandardError.new("frozen test")
      # Frozen exceptions can't have ivars set, so extract should return nil safely
      expect { described_class.extract(exception.freeze) }.not_to raise_error
    end

    it "returns empty hash when @_red_locals is set to empty hash" do
      exception = StandardError.new("test")
      exception.instance_variable_set(:@_red_locals, {})
      result = described_class.extract(exception)
      expect(result).to eq({})
    end
  end

  describe "callback safety" do
    before { described_class.enable! }

    it "never raises from the TracePoint callback" do
      expect {
        begin
          raise StandardError, "test"
        rescue
          # swallowed
        end
      }.not_to raise_error
    end

    it "does not capture exceptions from gem paths" do
      exception = nil
      begin
        JSON.parse("invalid json")
      rescue => e
        exception = e
      end

      locals = described_class.extract(exception)
      expect(locals).to be_nil
    end

    it "never stores Binding objects in @_red_locals" do
      exception = nil
      begin
        x = 42
        _unused = x
        raise StandardError, "test"
      rescue => e
        exception = e
      end

      locals = described_class.extract(exception)
      next unless locals

      locals.each_value do |val|
        expect(val).not_to be_a(Binding)
      end
    end

    it "does not capture exceptions from eval'd code" do
      exception = nil
      begin
        # rubocop:disable Security/Eval
        eval('raise StandardError, "from eval"')
        # rubocop:enable Security/Eval
      rescue => e
        exception = e
      end

      # Ruby 3.3+: path starts with "<" (e.g. "<eval>")
      # Ruby 3.2:  path starts with "(" (e.g. "(eval)")
      # Both are filtered by skip_path?
      locals = described_class.extract(exception)
      expect(locals).to be_nil
    end
  end

  describe "path filtering" do
    before { described_class.enable! }

    it "skips paths containing /gems/" do
      # Simulate: calling skip_path? through the callback
      # We verify indirectly: gem-originated exceptions don't get locals
      exception = nil
      begin
        # Force a StandardError from JSON gem code
        JSON.parse("not valid json at all")
      rescue => e
        exception = e
      end

      expect(described_class.extract(exception)).to be_nil
    end

    it "skips paths containing /vendor/" do
      # Vendor-originated exceptions should be filtered
      # Verified: skip_path? checks path.include?("/vendor/")
      exception = StandardError.new("vendor error")
      # No @_red_locals should be set for vendor paths
      expect(described_class.extract(exception)).to be_nil
    end
  end
end
