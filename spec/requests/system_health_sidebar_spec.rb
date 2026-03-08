# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System Health sidebar on error show page", type: :request do
  let!(:application) { create(:application) }

  before do
    RailsErrorDashboard.configuration.authenticate_with = -> { true }
    RailsErrorDashboard.configuration.enable_system_health = true
  end

  after do
    RailsErrorDashboard.configuration.authenticate_with = nil
    RailsErrorDashboard.configuration.enable_system_health = false
  end

  def create_error_with_health(health_hash)
    create(:error_log, application: application).tap do |e|
      e.update_column(:system_health, health_hash.to_json)
    end
  end

  describe "GET /error_dashboard/errors/:id" do
    context "when system_health contains ruby_vm data" do
      let!(:error_log) do
        create_error_with_health(
          ruby_vm: { constant_cache_invalidations: 1234, constant_cache_misses: 56, shape_cache_size: 789 },
          thread_count: 5,
          captured_at: Time.current.iso8601
        )
      end

      it "renders VM Cache Invalidations" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("VM Cache Invalidations:")
        expect(response.body).to include("1,234")
      end

      it "renders VM Cache Misses" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response.body).to include("VM Cache Misses:")
      end

      it "renders Shape Cache Size" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response.body).to include("Shape Cache Size:")
      end
    end

    context "when ruby_vm invalidations exceed 10,000" do
      let!(:error_log) do
        create_error_with_health(
          ruby_vm: { constant_cache_invalidations: 15_000, constant_cache_misses: 100 },
          captured_at: Time.current.iso8601
        )
      end

      it "renders with text-danger class" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        vm_section = response.body[/VM Cache Invalidations:.*?<\/div>/m]
        expect(vm_section).to include("text-danger")
        expect(vm_section).to include("15,000")
      end
    end

    context "when ruby_vm invalidations are below threshold" do
      let!(:error_log) do
        create_error_with_health(
          ruby_vm: { constant_cache_invalidations: 500, constant_cache_misses: 10 },
          captured_at: Time.current.iso8601
        )
      end

      it "does not render text-danger for invalidations" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        # Find the rendered div containing the invalidation value
        # When below threshold, the code element class should be "ms-1 " (no text-danger)
        expect(response.body).to include("VM Cache Invalidations:")
        expect(response.body).to include("500")
        # The code tag near the value should NOT have text-danger
        vm_section = response.body[/VM Cache Invalidations:.*?<\/div>/m]
        expect(vm_section).not_to include("text-danger")
      end
    end

    context "when system_health contains yjit data" do
      let!(:error_log) do
        create_error_with_health(
          yjit: {
            compiled_iseq_count: 100, compiled_block_count: 200,
            invalidation_count: 3, code_region_size: 524_288,
            compile_time_ns: 12_345_678
          },
          captured_at: Time.current.iso8601
        )
      end

      it "renders YJIT Compiled counts" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("YJIT Compiled:")
        expect(response.body).to include("100 iseqs")
        expect(response.body).to include("200 blocks")
      end

      it "renders YJIT Invalidations" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response.body).to include("YJIT Invalidations:")
      end

      it "renders YJIT Code Size in KB" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response.body).to include("YJIT Code Size:")
        expect(response.body).to include("512.0 KB")
      end

      it "renders YJIT Compile Time in ms" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response.body).to include("YJIT Compile Time:")
        expect(response.body).to include("12.35 ms")
      end
    end

    context "when yjit invalidation_count exceeds 100" do
      let!(:error_log) do
        create_error_with_health(
          yjit: { invalidation_count: 250 },
          captured_at: Time.current.iso8601
        )
      end

      it "renders with text-danger class" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        yjit_section = response.body[/YJIT Invalidations:.*?<\/div>/m]
        expect(yjit_section).to include("text-danger")
        expect(yjit_section).to include("250")
      end
    end

    context "when system_health has no ruby_vm key" do
      let!(:error_log) do
        create_error_with_health(
          thread_count: 5,
          captured_at: Time.current.iso8601
        )
      end

      it "does not render VM Cache section" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("VM Cache Invalidations:")
        expect(response.body).not_to include("VM Cache Misses:")
      end
    end

    context "when system_health has no yjit key" do
      let!(:error_log) do
        create_error_with_health(
          thread_count: 5,
          captured_at: Time.current.iso8601
        )
      end

      it "does not render YJIT section" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("YJIT Compiled:")
        expect(response.body).not_to include("YJIT Invalidations:")
      end
    end

    context "when yjit data has partial/missing keys" do
      let!(:error_log) do
        create_error_with_health(
          yjit: { invalidation_count: 5 },
          captured_at: Time.current.iso8601
        )
      end

      it "renders without error, hiding nil rows" do
        get "/error_dashboard/errors/#{error_log.id}"
        expect(response).to have_http_status(:ok)
        # invalidation_count present — should render
        expect(response.body).to include("YJIT Invalidations:")
        # compiled counts nil — should be hidden by guard
        expect(response.body).not_to include("YJIT Compiled:")
        # code_region_size nil — should be hidden by guard
        expect(response.body).not_to include("YJIT Code Size:")
        # compile_time_ns nil — should be hidden by guard
        expect(response.body).not_to include("YJIT Compile Time:")
      end
    end
  end
end
