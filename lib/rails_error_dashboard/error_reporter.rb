# frozen_string_literal: true

# Centralized Error Reporting for ALL errors in the application
# Uses Rails 7+ built-in error reporter - single source of truth
#
# This catches errors from:
# - Controllers (via ErrorHandler concern)
# - Background Jobs (via ActiveJob integration)
# - Sidekiq (via ActiveJob)
# - Services (if they use Rails.error.handle)
# - Model callbacks
# - Rake tasks
# - Console
# - Anywhere in the app
#
# Based on Rails 7+ Error Reporting Guide:
# https://guides.rubyonrails.org/error_reporting.html

module RailsErrorDashboard
  class ErrorReporter
    def report(error, handled:, severity:, context:, source: nil)
      # Skip low-severity warnings
      return if handled && severity == :warning

      # CRITICAL: Wrap entire process in rescue to ensure failures don't break the app
      begin
        # Extract context information
        error_context = ValueObjects::ErrorContext.new(context, source)

        # Log to our error dashboard using Command
        Commands::LogError.call(error, error_context.to_h.merge(source: source))
      rescue => e
        # Don't let error logging cause more errors - fail silently
        # Log failure for debugging but NEVER propagate exception
        Rails.logger.error("[RailsErrorDashboard] ErrorReporter failed: #{e.class} - #{e.message}")
        Rails.logger.error("Original error: #{error.class} - #{error.message}") if error
        Rails.logger.error("Context: #{context.inspect}") if context
        Rails.logger.error(e.backtrace&.first(5)&.join("\n")) if e.backtrace
        nil # Explicitly return nil, never raise
      end
    end
  end
end
