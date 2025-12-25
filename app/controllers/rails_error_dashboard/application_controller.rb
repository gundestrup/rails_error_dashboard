module RailsErrorDashboard
  class ApplicationController < ActionController::Base
    include Pagy::Backend

    layout "rails_error_dashboard"

    protect_from_forgery with: :exception

    # Make Pagy helpers available in views
    helper Pagy::Frontend

    # CRITICAL: Ensure dashboard errors never break the app
    # Catch all exceptions and render user-friendly error page
    rescue_from StandardError do |exception|
      # Log the error for debugging
      Rails.logger.error("[RailsErrorDashboard] Dashboard controller error: #{exception.class} - #{exception.message}")
      Rails.logger.error("Request: #{request.path} (#{request.method})")
      Rails.logger.error("Params: #{params.inspect}")
      Rails.logger.error(exception.backtrace&.first(10)&.join("\n")) if exception.backtrace

      # Render user-friendly error page
      render plain: "The Error Dashboard encountered an issue displaying this page.\n\n" \
                    "Your application is unaffected - this is only a dashboard display error.\n\n" \
                    "Error: #{exception.message}\n\n" \
                    "Check Rails logs for details: [RailsErrorDashboard]",
             status: :internal_server_error,
             layout: false
    end
  end
end
