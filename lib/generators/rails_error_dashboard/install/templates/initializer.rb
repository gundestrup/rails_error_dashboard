# frozen_string_literal: true

RailsErrorDashboard.configure do |config|
  # ============================================================================
  # AUTHENTICATION (Always Required)
  # ============================================================================

  # Dashboard authentication credentials
  # ⚠️ CHANGE THESE BEFORE PRODUCTION! ⚠️
  config.dashboard_username = ENV.fetch("ERROR_DASHBOARD_USER", "gandalf")
  config.dashboard_password = ENV.fetch("ERROR_DASHBOARD_PASSWORD", "youshallnotpass")

  # Require authentication for dashboard access
  config.require_authentication = true

  # Require authentication even in development mode
  config.require_authentication_in_development = false

  # ============================================================================
  # CORE FEATURES (Always Enabled)
  # ============================================================================

  # Error capture via middleware and Rails.error subscriber
  config.enable_middleware = true
  config.enable_error_subscriber = true

  # User model for error associations
  config.user_model = "User"

  # Error retention policy (days to keep errors before auto-deletion)
  config.retention_days = 90

  # ============================================================================
  # NOTIFICATION SETTINGS
  # ============================================================================
  # Configure which notification channels you want to use.
  # You can enable/disable any of these at any time by changing true/false.

<% if @enable_slack -%>
  # Slack Notifications - ENABLED
  config.enable_slack_notifications = true
  config.slack_webhook_url = ENV["SLACK_WEBHOOK_URL"]
  # To disable: Set config.enable_slack_notifications = false

<% else -%>
  # Slack Notifications - DISABLED
  # To enable: Set config.enable_slack_notifications = true and configure webhook URL
  config.enable_slack_notifications = false
  # config.slack_webhook_url = ENV["SLACK_WEBHOOK_URL"]

<% end -%>
<% if @enable_email -%>
  # Email Notifications - ENABLED
  config.enable_email_notifications = true
  config.notification_email_recipients = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip)
  config.notification_email_from = ENV.fetch("ERROR_NOTIFICATION_FROM", "errors@example.com")
  # To disable: Set config.enable_email_notifications = false

<% else -%>
  # Email Notifications - DISABLED
  # To enable: Set config.enable_email_notifications = true and configure recipients
  config.enable_email_notifications = false
  # config.notification_email_recipients = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip)
  # config.notification_email_from = ENV.fetch("ERROR_NOTIFICATION_FROM", "errors@example.com")

<% end -%>
<% if @enable_discord -%>
  # Discord Notifications - ENABLED
  config.enable_discord_notifications = true
  config.discord_webhook_url = ENV["DISCORD_WEBHOOK_URL"]
  # To disable: Set config.enable_discord_notifications = false

<% else -%>
  # Discord Notifications - DISABLED
  # To enable: Set config.enable_discord_notifications = true and configure webhook URL
  config.enable_discord_notifications = false
  # config.discord_webhook_url = ENV["DISCORD_WEBHOOK_URL"]

<% end -%>
<% if @enable_pagerduty -%>
  # PagerDuty Integration - ENABLED (critical errors only)
  config.enable_pagerduty_notifications = true
  config.pagerduty_integration_key = ENV["PAGERDUTY_INTEGRATION_KEY"]
  # To disable: Set config.enable_pagerduty_notifications = false

<% else -%>
  # PagerDuty Integration - DISABLED
  # To enable: Set config.enable_pagerduty_notifications = true and configure integration key
  config.enable_pagerduty_notifications = false
  # config.pagerduty_integration_key = ENV["PAGERDUTY_INTEGRATION_KEY"]

<% end -%>
<% if @enable_webhooks -%>
  # Generic Webhook Notifications - ENABLED
  config.enable_webhook_notifications = true
  config.webhook_urls = ENV.fetch("WEBHOOK_URLS", "").split(",").map(&:strip).reject(&:empty?)
  # To disable: Set config.enable_webhook_notifications = false

<% else -%>
  # Generic Webhook Notifications - DISABLED
  # To enable: Set config.enable_webhook_notifications = true and configure webhook URLs
  config.enable_webhook_notifications = false
  # config.webhook_urls = ENV.fetch("WEBHOOK_URLS", "").split(",").map(&:strip).reject(&:empty?)

<% end -%>
  # Dashboard base URL (used in notification links)
  config.dashboard_base_url = ENV["DASHBOARD_BASE_URL"]

  # ============================================================================
  # PERFORMANCE & SCALABILITY
  # ============================================================================

<% if @enable_async_logging -%>
  # Async Error Logging - ENABLED
  # Errors will be logged in background jobs for better performance
  config.async_logging = true
  config.async_adapter = :sidekiq  # Options: :sidekiq, :solid_queue, :async
  # To disable: Set config.async_logging = false

<% else -%>
  # Async Error Logging - DISABLED
  # Errors are logged synchronously (blocking)
  # To enable: Set config.async_logging = true and configure adapter
  config.async_logging = false
  # config.async_adapter = :sidekiq  # Options: :sidekiq, :solid_queue, :async

<% end -%>
  # Backtrace size limiting (reduces storage by ~80%)
  config.max_backtrace_lines = 50

  # Error sampling rate (1.0 = 100%, log all errors)
  # Reduce for high-traffic apps: 0.1 = log 10% of non-critical errors
  # Critical errors are ALWAYS logged regardless of sampling rate
  config.sampling_rate = 1.0

  # Ignored exceptions (skip logging these)
  # config.ignored_exceptions = [
  #   "ActionController::RoutingError",
  #   "ActionController::InvalidAuthenticityToken",
  #   /^ActiveRecord::RecordNotFound/
  # ]

  # ============================================================================
  # DATABASE CONFIGURATION
  # ============================================================================

<% if @enable_separate_database -%>
  # Separate Error Database - ENABLED
  # Errors will be stored in a dedicated database
  # See docs/guides/DATABASE_OPTIONS.md for setup instructions
  config.use_separate_database = true
  # To disable: Set config.use_separate_database = false

<% else -%>
  # Separate Error Database - DISABLED
  # Errors are stored in your main application database
  # To enable: Set config.use_separate_database = true and configure database.yml
  config.use_separate_database = false

<% end -%>
  # ============================================================================
  # ADVANCED FEATURES
  # ============================================================================

  # Baseline monitoring and anomaly detection
  # Automatically detect when error rates exceed normal patterns
  config.enable_baseline_alerts = ENV.fetch("ENABLE_BASELINE_ALERTS", "true") == "true"
  config.baseline_alert_threshold_std_devs = ENV.fetch("BASELINE_ALERT_THRESHOLD", "2.0").to_f
  config.baseline_alert_severities = [ :critical, :high ]
  config.baseline_alert_cooldown_minutes = ENV.fetch("BASELINE_ALERT_COOLDOWN", "120").to_i

  # Custom severity rules (override automatic severity classification)
  # config.custom_severity_rules = {
  #   "PaymentError" => :critical,
  #   "ValidationError" => :low
  # }

  # Enhanced metrics (optional)
  config.app_version = ENV["APP_VERSION"]
  config.git_sha = ENV["GIT_SHA"]
  # config.total_users_for_impact = 10000  # For user impact % calculation
end
