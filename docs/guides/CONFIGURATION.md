# Configuration Guide

This guide covers all configuration options for Rails Error Dashboard, including advanced features for customization and extensibility.

## Table of Contents

- [Basic Configuration](#basic-configuration)
- [Custom Severity Classification](#custom-severity-classification)
- [Ignored Exceptions](#ignored-exceptions)
- [Error Sampling](#error-sampling)
- [Notification Callbacks](#notification-callbacks)
- [ActiveSupport Notifications](#activesupport-notifications)
- [Async Logging](#async-logging)
- [Backtrace Configuration](#backtrace-configuration)
- [Complete Configuration Example](#complete-configuration-example)

---

## Basic Configuration

Create an initializer at `config/initializers/rails_error_dashboard.rb`:

```ruby
RailsErrorDashboard.configure do |config|
  # Dashboard authentication
  config.dashboard_username = "admin"
  config.dashboard_password = ENV.fetch("ERROR_DASHBOARD_PASSWORD", "changeme")
  config.require_authentication = true

  # Data retention (days)
  config.retention_days = 90

  # User model for error association
  config.user_model = "User"

  # Enable/disable middleware and error subscriber
  config.enable_middleware = true
  config.enable_error_subscriber = true
end
```

---

## Custom Severity Classification

Override default severity levels for specific error types. This is useful when you want to treat certain errors differently than the defaults.

### Default Severity Levels

- **Critical**: `SecurityError`, `NoMemoryError`, `SystemStackError`, `ActiveRecord::StatementInvalid`
- **High**: `ActiveRecord::RecordNotFound`, `ArgumentError`, `TypeError`, `NoMethodError`, `NameError`
- **Medium**: `ActiveRecord::RecordInvalid`, `Timeout::Error`, `Net::ReadTimeout`, `Net::OpenTimeout`
- **Low**: All other errors

### Configuration

```ruby
RailsErrorDashboard.configure do |config|
  config.custom_severity_rules = {
    # Treat payment errors as critical
    "Stripe::CardError" => :critical,
    "PaymentProcessingError" => :critical,

    # Downgrade validation errors to low
    "ActiveRecord::RecordInvalid" => :low,

    # Custom application errors
    "MyApp::BusinessLogicError" => :medium
  }
end
```

### Use Cases

- **Payment Errors**: Treat as critical to ensure immediate attention
- **Validation Errors**: Downgrade to low if they're expected user input errors
- **Third-party API Errors**: Classify based on business impact
- **Custom Application Errors**: Set appropriate severity for domain-specific errors

---

## Ignored Exceptions

Prevent certain exceptions from being logged. Useful for reducing noise from expected errors or third-party gems.

### Configuration

```ruby
RailsErrorDashboard.configure do |config|
  config.ignored_exceptions = [
    # Exact class names
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound",

    # Regex patterns for flexible matching
    /Rack::Timeout/,
    /ActionController::InvalidAuthenticityToken/,

    # All errors from a specific namespace
    /ThirdPartyGem::.*/
  ]
end
```

### Features

- **Exact Matching**: Specify exception class names as strings
- **Regex Patterns**: Use regular expressions for flexible matching
- **Inheritance Support**: Ignoring a parent class ignores all subclasses
- **Early Exit**: Ignored exceptions skip all processing, saving resources

### Use Cases

```ruby
# Production: Ignore bot-related errors
config.ignored_exceptions = [
  "ActionController::RoutingError",  # Bots scanning for vulnerabilities
  /ActionController::InvalidAuthenticityToken/  # CSRF from legitimate crawlers
]

# Development: Ignore known third-party issues
config.ignored_exceptions = [
  /Geocoder::.*/,  # Geocoding API rate limits
  "Redis::CannotConnectError"  # Redis disconnects during development
]
```

---

## Error Sampling

Reduce database load by logging only a percentage of non-critical errors. **Critical errors are ALWAYS logged** regardless of sampling rate.

### Configuration

```ruby
RailsErrorDashboard.configure do |config|
  # Log 100% of errors (default)
  config.sampling_rate = 1.0

  # Log only 10% of non-critical errors (critical errors always logged)
  config.sampling_rate = 0.1

  # Disable logging of non-critical errors entirely
  config.sampling_rate = 0.0
end
```

### Behavior

- **1.0 (100%)**: Log all errors - default behavior
- **0.1 (10%)**: Log 10% of non-critical errors, 100% of critical errors
- **0.0 (0%)**: Skip all non-critical errors, log only critical errors
- **> 1.0**: Treated as 100%
- **< 0.0**: Treated as 0%

### Critical Errors (Always Logged)

These errors bypass sampling because they indicate serious system issues:
- `SecurityError`
- `NoMemoryError`
- `SystemStackError`
- `ActiveRecord::StatementInvalid`

### Use Cases

```ruby
# High-traffic production: Reduce database writes
config.sampling_rate = 0.1  # 10% sampling

# Load testing: Only log critical issues
config.sampling_rate = 0.0  # Skip non-critical

# Monitoring phase: Full visibility
config.sampling_rate = 1.0  # Log everything
```

---

## Notification Callbacks

Register custom Ruby blocks that execute when errors are logged or resolved. Perfect for integrating with external services.

### Available Callbacks

#### 1. `on_error_logged` - Any Error Logged

```ruby
RailsErrorDashboard.on_error_logged do |error_log|
  # Called for every NEW error (not recurrences)

  # Send to custom logging service
  CustomLogger.log(
    level: error_log.severity,
    message: error_log.message,
    metadata: {
      error_type: error_log.error_type,
      platform: error_log.platform,
      environment: error_log.environment
    }
  )
end
```

#### 2. `on_critical_error` - Critical Errors Only

```ruby
RailsErrorDashboard.on_critical_error do |error_log|
  # Called ONLY for critical errors (in addition to on_error_logged)

  # Trigger PagerDuty incident
  PagerDuty.trigger(
    summary: "Critical: #{error_log.error_type}",
    severity: "critical",
    source: error_log.platform,
    custom_details: {
      message: error_log.message,
      backtrace: error_log.backtrace&.lines&.first(5)
    }
  )
end
```

#### 3. `on_error_resolved` - Error Resolved

```ruby
RailsErrorDashboard.on_error_resolved do |error_log|
  # Called when error is marked as resolved

  # Notify team
  Slack.post_message(
    channel: "#engineering",
    text: "✅ Error resolved: #{error_log.error_type}",
    attachments: [{
      fields: [
        { title: "Resolved By", value: error_log.resolved_by_name },
        { title: "Occurrences", value: error_log.occurrence_count },
        { title: "Resolution", value: error_log.resolution_comment }
      ]
    }]
  )
end
```

### Multiple Callbacks

You can register multiple callbacks for the same event:

```ruby
# Callback 1: Log to external service
RailsErrorDashboard.on_error_logged do |error_log|
  Datadog.increment("errors.logged", tags: ["type:#{error_log.error_type}"])
end

# Callback 2: Send to analytics
RailsErrorDashboard.on_error_logged do |error_log|
  Analytics.track_error(error_log)
end

# Both callbacks will execute
```

### Error Handling

Callbacks are fail-safe - if one callback raises an error, it won't break error logging or prevent other callbacks from running:

```ruby
RailsErrorDashboard.on_error_logged do |error_log|
  raise "Callback error"  # Logged as warning, other callbacks still run
end

RailsErrorDashboard.on_error_logged do |error_log|
  puts "This still executes"  # ✓ Runs even if previous callback failed
end
```

### Integration Examples

#### Datadog

```ruby
RailsErrorDashboard.on_error_logged do |error_log|
  Datadog::Statsd.increment("errors.logged",
    tags: [
      "severity:#{error_log.severity}",
      "platform:#{error_log.platform}",
      "environment:#{error_log.environment}"
    ]
  )
end
```

#### Sentry (alongside Error Dashboard)

```ruby
RailsErrorDashboard.on_critical_error do |error_log|
  Sentry.capture_message(
    "Critical Error: #{error_log.error_type}",
    level: :fatal,
    extra: {
      error_id: error_log.id,
      message: error_log.message,
      platform: error_log.platform
    }
  )
end
```

#### Custom Metrics

```ruby
RailsErrorDashboard.on_error_logged do |error_log|
  Prometheus.error_counter.increment(
    labels: {
      type: error_log.error_type,
      severity: error_log.severity,
      platform: error_log.platform
    }
  )
end
```

---

## ActiveSupport Notifications

Rails Error Dashboard emits standard Rails instrumentation events that can be subscribed to using `ActiveSupport::Notifications`.

### Available Events

#### 1. `error_logged.rails_error_dashboard`

Emitted when any error is logged (new errors only, not recurrences).

```ruby
ActiveSupport::Notifications.subscribe("error_logged.rails_error_dashboard") do |name, start, finish, id, payload|
  # Payload contains:
  # - error_log: Full ErrorLog record
  # - error_id: Error ID
  # - error_type: Exception class name
  # - message: Error message
  # - severity: Error severity (:critical, :high, :medium, :low)
  # - platform: Platform (iOS, Android, API)
  # - environment: Rails environment
  # - occurred_at: Timestamp

  duration = finish - start
  StatsD.timing("error_logging.duration", duration)
  StatsD.increment("errors.logged", tags: ["type:#{payload[:error_type]}"])
end
```

#### 2. `critical_error.rails_error_dashboard`

Emitted when a critical error is logged (in addition to `error_logged`).

```ruby
ActiveSupport::Notifications.subscribe("critical_error.rails_error_dashboard") do |name, start, finish, id, payload|
  # Same payload as error_logged

  # Trigger immediate alert
  PagerDuty.trigger_incident(
    title: "Critical Error: #{payload[:error_type]}",
    severity: "critical",
    details: payload[:message]
  )
end
```

#### 3. `error_resolved.rails_error_dashboard`

Emitted when an error is marked as resolved.

```ruby
ActiveSupport::Notifications.subscribe("error_resolved.rails_error_dashboard") do |name, start, finish, id, payload|
  # Payload contains:
  # - error_log: Full ErrorLog record
  # - error_id: Error ID
  # - error_type: Exception class name
  # - resolved_by: Name of person who resolved it
  # - resolved_at: Timestamp

  Analytics.track_resolution(
    error_id: payload[:error_id],
    resolved_by: payload[:resolved_by],
    resolution_time: payload[:resolved_at] - payload[:error_log].occurred_at
  )
end
```

### Using Event Objects

```ruby
ActiveSupport::Notifications.subscribe("error_logged.rails_error_dashboard") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  puts "Event: #{event.name}"
  puts "Duration: #{event.duration}ms"
  puts "Error Type: #{event.payload[:error_type]}"
  puts "Severity: #{event.payload[:severity]}"
end
```

### Wildcard Subscriptions

```ruby
# Subscribe to all Rails Error Dashboard events
ActiveSupport::Notifications.subscribe(/rails_error_dashboard/) do |event|
  Rails.logger.info "Error Dashboard Event: #{event.name}"
end
```

### Integration Examples

#### NewRelic

```ruby
ActiveSupport::Notifications.subscribe("critical_error.rails_error_dashboard") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  NewRelic::Agent.notice_error(
    StandardError.new(event.payload[:message]),
    custom_params: {
      error_id: event.payload[:error_id],
      platform: event.payload[:platform]
    }
  )
end
```

#### Prometheus

```ruby
error_counter = Prometheus::Client::Counter.new(
  :rails_errors_total,
  docstring: "Total number of Rails errors",
  labels: [:type, :severity, :platform]
)

ActiveSupport::Notifications.subscribe("error_logged.rails_error_dashboard") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  error_counter.increment(
    labels: {
      type: event.payload[:error_type],
      severity: event.payload[:severity],
      platform: event.payload[:platform]
    }
  )
end
```

#### Elasticsearch

```ruby
ActiveSupport::Notifications.subscribe("error_logged.rails_error_dashboard") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  Elasticsearch::Client.new.index(
    index: "rails-errors",
    body: {
      timestamp: event.payload[:occurred_at],
      error_type: event.payload[:error_type],
      message: event.payload[:message],
      severity: event.payload[:severity],
      platform: event.payload[:platform],
      environment: event.payload[:environment]
    }
  )
end
```

---

## Async Logging

*Note: Async logging will be available in Phase 2.1 - coming soon.*

Configure asynchronous error logging to prevent blocking your application:

```ruby
RailsErrorDashboard.configure do |config|
  # Enable async logging
  config.async_logging = true

  # Choose adapter: :sidekiq (default), :solid_queue, or :async
  config.async_adapter = :sidekiq
end
```

---

## Backtrace Configuration

Control how many lines of backtrace are stored:

```ruby
RailsErrorDashboard.configure do |config|
  # Limit backtrace to 50 lines (default)
  config.max_backtrace_lines = 50

  # Store more for detailed debugging
  config.max_backtrace_lines = 100

  # Minimal storage (just the first line)
  config.max_backtrace_lines = 1
end
```

**Benefits:**
- Reduced database storage
- Faster error logging
- Still captures the most relevant stack frames

---

## Complete Configuration Example

Here's a production-ready configuration combining multiple features:

```ruby
# config/initializers/rails_error_dashboard.rb

RailsErrorDashboard.configure do |config|
  # === Authentication ===
  config.dashboard_username = "admin"
  config.dashboard_password = ENV.fetch("ERROR_DASHBOARD_PASSWORD")
  config.require_authentication = true

  # === Data Management ===
  config.retention_days = 90
  config.user_model = "User"

  # === Custom Severity ===
  config.custom_severity_rules = {
    "Stripe::CardError" => :critical,
    "PaymentProcessingError" => :critical,
    "ActiveRecord::RecordInvalid" => :low
  }

  # === Ignored Exceptions ===
  config.ignored_exceptions = [
    "ActionController::RoutingError",
    /ActionController::InvalidAuthenticityToken/,
    /Rack::Timeout/
  ]

  # === Performance ===
  config.sampling_rate = 0.1  # Log 10% of non-critical errors
  config.max_backtrace_lines = 50

  # === Features ===
  config.enable_middleware = true
  config.enable_error_subscriber = true
end

# === Notification Callbacks ===

# Alert on critical errors
RailsErrorDashboard.on_critical_error do |error_log|
  PagerDuty.trigger(
    summary: "Critical: #{error_log.error_type}",
    severity: "critical",
    source: error_log.platform
  )
end

# Track metrics
RailsErrorDashboard.on_error_logged do |error_log|
  StatsD.increment("errors.logged",
    tags: [
      "type:#{error_log.error_type}",
      "severity:#{error_log.severity}",
      "platform:#{error_log.platform}"
    ]
  )
end

# Notify on resolution
RailsErrorDashboard.on_error_resolved do |error_log|
  Slack.post_message(
    channel: "#engineering",
    text: "✅ #{error_log.error_type} resolved by #{error_log.resolved_by_name}"
  )
end

# === ActiveSupport Notifications ===

# Send to external logging service
ActiveSupport::Notifications.subscribe("error_logged.rails_error_dashboard") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  Elasticsearch::Client.new.index(
    index: "rails-errors",
    body: {
      timestamp: event.payload[:occurred_at],
      error_type: event.payload[:error_type],
      message: event.payload[:message],
      severity: event.payload[:severity],
      platform: event.payload[:platform]
    }
  )
end
```

---

## Environment-Specific Configuration

Configure differently per environment:

```ruby
RailsErrorDashboard.configure do |config|
  # Common configuration
  config.user_model = "User"
  config.max_backtrace_lines = 50

  if Rails.env.production?
    # Production: Aggressive sampling, strict filtering
    config.sampling_rate = 0.1
    config.ignored_exceptions = [
      "ActionController::RoutingError",
      /ActionController::InvalidAuthenticityToken/
    ]

  elsif Rails.env.staging?
    # Staging: Moderate sampling
    config.sampling_rate = 0.5

  else
    # Development/Test: Log everything
    config.sampling_rate = 1.0
    config.ignored_exceptions = []
  end
end
```

---

## Resetting Configuration

For testing or dynamic reconfiguration:

```ruby
# Reset to defaults
RailsErrorDashboard.reset_configuration!

# Reconfigure
RailsErrorDashboard.configure do |config|
  config.sampling_rate = 1.0
end
```

---

## Next Steps

- **Phase 2 Features**: Async logging, database optimization, performance tuning
- **Testing**: Write tests for your custom callbacks and severity rules
- **Monitoring**: Set up ActiveSupport::Notifications subscribers for your metrics service

For questions or issues, visit: https://github.com/yourusername/rails_error_dashboard
