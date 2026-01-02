module RailsErrorDashboard
  class Engine < ::Rails::Engine
    isolate_namespace RailsErrorDashboard

    # Initialize the engine
    initializer "rails_error_dashboard.middleware" do |app|
      # Enable Flash middleware for Error Dashboard routes in API-only apps
      # This ensures flash messages work even when config.api_only = true
      if app.config.api_only
        # Insert Flash middleware ONLY for Error Dashboard routes
        app.middleware.use ActionDispatch::Flash
        app.middleware.use ActionDispatch::Cookies
        app.middleware.use ActionDispatch::Session::CookieStore
      end

      # Add error catching middleware if enabled
      if RailsErrorDashboard.configuration.enable_middleware
        app.config.middleware.insert_before 0, RailsErrorDashboard::Middleware::ErrorCatcher
      end

      # Add rate limiting middleware if enabled
      if RailsErrorDashboard.configuration.enable_rate_limiting
        app.config.middleware.use RailsErrorDashboard::Middleware::RateLimiter
      end
    end

    # Subscribe to Rails error reporter
    config.after_initialize do
      if RailsErrorDashboard.configuration.enable_error_subscriber
        Rails.error.subscribe(RailsErrorDashboard::ErrorReporter.new)
      end
    end
  end
end
