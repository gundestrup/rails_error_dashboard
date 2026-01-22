# frozen_string_literal: true

module RailsErrorDashboard
  # Custom exception for configuration validation errors
  # Provides clear, actionable error messages when configuration is invalid
  class ConfigurationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors.is_a?(Array) ? errors : [ errors ]
      super(build_message)
    end

    private

    def build_message
      header = "Rails Error Dashboard configuration is invalid:\n\n"
      body = @errors.map.with_index(1) { |error, index| "  #{index}. #{error}" }.join("\n")
      footer = "\n\nPlease fix these issues in config/initializers/rails_error_dashboard.rb"

      header + body + footer
    end
  end
end
