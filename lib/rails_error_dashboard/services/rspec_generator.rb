# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # Pure algorithm: Assemble an RSpec request spec from an error log's request data
    #
    # Operates on data already stored in ErrorLog — zero runtime cost.
    # Called at display time only.
    #
    # @example
    #   RailsErrorDashboard::Services::RspecGenerator.call(error)
    #   # => "RSpec.describe 'POST /users', type: :request do\n  it 'reproduces the error' do\n    ..."
    class RspecGenerator
      BODY_METHODS = %w[ POST PUT PATCH DELETE ].freeze

      # @param error [ErrorLog] An error log record
      # @return [String] RSpec request spec string, or "" if insufficient data
      def self.call(error)
        new(error).generate
      rescue => e
        ""
      end

      def initialize(error)
        @error = error
      end

      # @return [String]
      def generate
        path = request_path
        return "" if path.blank?

        method = http_method
        lines = []
        lines << header_lines(method, path)
        lines << ""
        lines << "  it \"reproduces the error\" do"
        lines << request_line(method, path)
        lines << ""
        lines << "    # Original error: #{error_type}"
        lines << "    # Expect the response to indicate the error"
        lines << "    expect(response).to have_http_status(:internal_server_error)"
        lines << "  end"
        lines << "end"

        lines.join("\n")
      rescue => e
        ""
      end

      private

      def header_lines(method, path)
        "RSpec.describe \"#{method} #{path}\", type: :request do"
      end

      def request_line(method, path)
        verb = method.downcase
        parts = []

        if BODY_METHODS.include?(method) && parsed_params.present?
          params_str = format_params(parsed_params)
          headers_str = format_headers

          args = [ "\"#{path}\"" ]
          args << "params: #{params_str}"
          args << "headers: #{headers_str}" if headers_str

          parts << "    #{verb} #{args.join(', ')}"
        else
          query_params = extract_query_params(path)
          clean_path = path.split("?").first

          if query_params.present?
            params_str = format_params(query_params)
            parts << "    #{verb} \"#{clean_path}\", params: #{params_str}"
          else
            parts << "    #{verb} \"#{path}\""
          end
        end

        parts.join("\n")
      end

      def http_method
        method = @error.respond_to?(:http_method) && @error.http_method.presence
        (method || "GET").upcase
      end

      def request_path
        url = @error.respond_to?(:request_url) && @error.request_url.presence
        return nil if url.blank?

        # Strip scheme + host to get just the path
        if url.start_with?("http://", "https://")
          URI.parse(url).request_uri
        else
          url
        end
      rescue URI::InvalidURIError
        url
      end

      def error_type
        @error.respond_to?(:error_type) && @error.error_type.presence || "Unknown"
      end

      def parsed_params
        raw = @error.respond_to?(:request_params) && @error.request_params.presence
        return nil if raw.blank?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end

      def extract_query_params(path)
        query = path.split("?", 2).last
        return nil if query == path || query.blank?

        Rack::Utils.parse_query(query)
      rescue => e
        nil
      end

      def format_params(hash)
        return nil if hash.blank?

        pairs = hash.map { |k, v| "#{format_key(k)} => #{v.inspect}" }
        "{ #{pairs.join(', ')} }"
      end

      def format_headers
        content_type = @error.respond_to?(:content_type) && @error.content_type.presence
        return nil if content_type.blank?

        "{ \"Content-Type\" => #{content_type.inspect} }"
      end

      def format_key(key)
        key.to_s.inspect
      end
    end
  end
end
