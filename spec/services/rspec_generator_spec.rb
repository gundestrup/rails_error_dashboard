# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Services::RspecGenerator do
  def make_error(attrs = {})
    defaults = {
      http_method: "GET",
      hostname: "example.com",
      request_url: "/users",
      request_params: nil,
      content_type: nil,
      user_agent: nil,
      error_type: "NoMethodError"
    }
    double("ErrorLog", defaults.merge(attrs))
  end

  describe ".call" do
    it "generates a GET request spec" do
      error = make_error(http_method: "GET", request_url: "/users")
      result = described_class.call(error)

      expect(result).to include('RSpec.describe "GET /users", type: :request do')
      expect(result).to include('get "/users"')
      expect(result).to include("expect(response).to have_http_status(:internal_server_error)")
    end

    it "generates a POST request spec with params and headers" do
      error = make_error(
        http_method: "POST",
        request_url: "/users",
        request_params: '{"name":"test","email":"a@b.com"}',
        content_type: "application/json"
      )
      result = described_class.call(error)

      expect(result).to include('RSpec.describe "POST /users", type: :request do')
      expect(result).to include("post")
      expect(result).to include('"name" => "test"')
      expect(result).to include('"email" => "a@b.com"')
      expect(result).to include('"Content-Type" => "application/json"')
    end

    it "generates a PUT request spec with body params" do
      error = make_error(
        http_method: "PUT",
        request_url: "/users/1",
        request_params: '{"name":"updated"}'
      )
      result = described_class.call(error)

      expect(result).to include('RSpec.describe "PUT /users/1", type: :request do')
      expect(result).to include("put")
      expect(result).to include('"name" => "updated"')
    end

    it "generates a PATCH request spec with body params" do
      error = make_error(
        http_method: "PATCH",
        request_url: "/users/1",
        request_params: '{"name":"patched"}'
      )
      result = described_class.call(error)

      expect(result).to include("patch")
      expect(result).to include('"name" => "patched"')
    end

    it "generates a DELETE request spec with body params" do
      error = make_error(
        http_method: "DELETE",
        request_url: "/users/1",
        request_params: '{"confirm":"true"}'
      )
      result = described_class.call(error)

      expect(result).to include("delete")
      expect(result).to include('"confirm" => "true"')
    end

    it "extracts query params from GET URL" do
      error = make_error(
        http_method: "GET",
        request_url: "/users?page=2&per_page=25"
      )
      result = described_class.call(error)

      expect(result).to include('get "/users"')
      expect(result).to include('"page" => "2"')
      expect(result).to include('"per_page" => "25"')
    end

    it "strips scheme and host from absolute URLs" do
      error = make_error(
        http_method: "GET",
        request_url: "https://api.example.com/v1/users?page=2"
      )
      result = described_class.call(error)

      expect(result).to include('RSpec.describe "GET /v1/users?page=2", type: :request do')
      expect(result).to include('get "/v1/users"')
    end

    it "includes the original error type as a comment" do
      error = make_error(error_type: "ActiveRecord::RecordNotFound")
      result = described_class.call(error)

      expect(result).to include("# Original error: ActiveRecord::RecordNotFound")
    end

    it "returns empty string when request_url is missing" do
      error = make_error(request_url: nil)
      expect(described_class.call(error)).to eq("")
    end

    it "returns empty string when request_url is blank" do
      error = make_error(request_url: "")
      expect(described_class.call(error)).to eq("")
    end

    it "defaults to GET when http_method is nil" do
      error = make_error(http_method: nil, request_url: "/test")
      result = described_class.call(error)

      expect(result).to include("GET /test")
      expect(result).to include('get "/test"')
    end

    it "handles malformed JSON params gracefully" do
      error = make_error(
        http_method: "POST",
        request_url: "/users",
        request_params: "not valid json {{{"
      )
      result = described_class.call(error)

      expect(result).to include("post")
      expect(result).not_to include("params:")
    end

    it "returns empty string on nil input" do
      expect(described_class.call(nil)).to eq("")
    end

    it "returns empty string when error raises" do
      error = double("BrokenError")
      allow(error).to receive(:respond_to?).and_raise(RuntimeError, "boom")
      expect(described_class.call(error)).to eq("")
    end

    it "omits headers when content_type is blank" do
      error = make_error(
        http_method: "POST",
        request_url: "/users",
        request_params: '{"name":"test"}',
        content_type: nil
      )
      result = described_class.call(error)

      expect(result).not_to include("headers:")
    end

    it "produces valid RSpec structure" do
      error = make_error(http_method: "GET", request_url: "/test")
      result = described_class.call(error)

      expect(result).to start_with("RSpec.describe")
      expect(result).to include("it \"reproduces the error\" do")
      expect(result).to end_with("end")
    end
  end
end
