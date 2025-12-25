# frozen_string_literal: true

RailsErrorDashboard.configure do |config|
  # Dashboard authentication credentials
  # ⚠️ CHANGE THESE BEFORE PRODUCTION! ⚠️
  config.dashboard_username = ENV.fetch("ERROR_DASHBOARD_USER", "gandalf")
  config.dashboard_password = ENV.fetch("ERROR_DASHBOARD_PASSWORD", "youshallnotpass")

  # Require authentication for dashboard access
  # Set to false to disable authentication (not recommended in production)
  config.require_authentication = true

  # Require authentication even in development mode
  # Set to true if you want to test authentication in development
  config.require_authentication_in_development = false

  # User model for associations (defaults to 'User')
  # Change this if your user model has a different name
  config.user_model = "User"

  # === NOTIFICATION SETTINGS ===
  #
  # Notifications are sent asynchronously via the :error_notifications queue
  # Works with: Solid Queue (Rails 8.1+), Sidekiq, Delayed Job, Resque, etc.
  #
  # For Sidekiq, add to config/sidekiq.yml:
  #   :queues:
  #     - error_notifications
  #     - default
  #
  # For Solid Queue (Rails 8.1+), add to config/queue.yml:
  #   workers:
  #     - queues: error_notifications
  #       threads: 3

  # Slack notifications
  config.enable_slack_notifications = true
  config.slack_webhook_url = ENV["SLACK_WEBHOOK_URL"]

  # Email notifications
  config.enable_email_notifications = true
  config.notification_email_recipients = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip)
  config.notification_email_from = ENV.fetch("ERROR_NOTIFICATION_FROM", "errors@example.com")

  # Dashboard base URL (used in notification links)
  # Example: 'https://myapp.com' or 'http://localhost:3000'
  config.dashboard_base_url = ENV["DASHBOARD_BASE_URL"]

  # Use a separate database for error logs (optional)
  # See documentation for setup instructions: docs/SEPARATE_ERROR_DATABASE.md
  config.use_separate_database = ENV.fetch("USE_SEPARATE_ERROR_DB", "false") == "true"

  # Retention policy - number of days to keep error logs
  # Old errors will be automatically deleted after this many days
  config.retention_days = 90

  # Enable/disable error catching middleware
  # Set to false if you want to handle errors differently
  config.enable_middleware = true

  # Enable/disable Rails.error subscriber
  # Set to false if you don't want to use Rails error reporting
  config.enable_error_subscriber = true

  # === PHASE 2: PERFORMANCE & SCALABILITY ===

  # Backtrace size limiting
  # Limits stored backtrace to N lines to reduce database size
  # Full backtraces can be 100+ lines, but first 50 usually have the relevant info
  # Reduces storage by up to 80% with minimal information loss
  # config.max_backtrace_lines = 50

  # Async error logging
  # Process error logging in background jobs for better performance
  # Prevents errors from blocking your main request/response cycle
  # config.async_logging = true
  # config.async_adapter = :sidekiq  # or :solid_queue, :async

  # Error sampling rate (0.0 to 1.0)
  # Sample non-critical errors to reduce volume in high-traffic apps
  # 1.0 = log all errors (default)
  # 0.1 = log 10% of non-critical errors
  # Critical errors (SecurityError, NoMemoryError, etc.) are ALWAYS logged
  # config.sampling_rate = 1.0

  # Ignored exceptions
  # Skip logging certain exception types
  # Supports exact class names and regex patterns
  # config.ignored_exceptions = [
  #   "ActionController::RoutingError",
  #   "ActionController::InvalidAuthenticityToken",
  #   /^ActiveRecord::RecordNotFound/
  # ]
end
