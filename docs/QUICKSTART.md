# Quickstart Guide

Get Rails Error Dashboard up and running in 5 minutes!

## Prerequisites

- Rails 7.0 or later
- Ruby 3.0 or later
- SQLite, PostgreSQL, or MySQL database

## Installation

### 1. Add to Gemfile

```ruby
gem 'rails_error_dashboard'
```

### 2. Install

```bash
bundle install
rails generate rails_error_dashboard:install
rails db:migrate
```

That's it! The dashboard is now available at `/error_dashboard` in your Rails app.

## First Steps

### Access the Dashboard

Visit `http://localhost:3000/error_dashboard` to see the error dashboard.

Initially, you won't see any errors. Let's create one to test:

```ruby
# In rails console
raise "Test error from console"
```

Or create a controller error:

```ruby
# app/controllers/home_controller.rb
class HomeController < ApplicationController
  def index
    raise "Test error from controller"
  end
end
```

Visit the route and check `/errors` - you should see your test error!

### Configure Basic Settings

Edit `config/initializers/rails_error_dashboard.rb`:

```ruby
RailsErrorDashboard.configure do |config|
  # Basic authentication (change these!)
  config.username = "admin"
  config.password = "your_secure_password"

  # Enable async logging for better performance
  config.async_logging = true
  config.async_adapter = :sidekiq  # or :solid_queue, :async

  # Limit backtrace size
  config.max_backtrace_lines = 50
end
```

**Important**: Change the default username and password before deploying to production!

## Essential Features

### 1. Error Notifications (Slack)

Get notified when critical errors occur:

```ruby
RailsErrorDashboard.configure do |config|
  config.enable_slack_notifications = true
  config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
end
```

Set your Slack webhook URL:
```bash
# .env
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### 2. Custom Severity Rules

Mark certain errors as critical:

```ruby
RailsErrorDashboard.configure do |config|
  config.custom_severity_rules = {
    'PaymentError' => :critical,
    'SecurityError' => :critical,
    'DataLossError' => :critical,
    'ValidationError' => :low
  }
end
```

### 3. Sampling (High-Traffic Apps)

For high-traffic applications, sample errors to reduce storage:

```ruby
RailsErrorDashboard.configure do |config|
  config.sampling_rate = 0.1  # Log 10% of errors
end
```

## Common Tasks

### Resolve an Error

1. Go to `/errors`
2. Click on an error
3. Click "Mark as Resolved"
4. Add a resolution comment (optional)

### Batch Delete Errors

1. Go to `/errors`
2. Select errors using checkboxes
3. Click "Bulk Actions" → "Delete Selected"

### Filter Errors

Use the sidebar filters:
- **Platform**: iOS, Android, API, Web
- **Unresolved**: Show only unresolved errors
- **Search**: Search by error message

## Next Steps

Now that you have the basics working:

1. **Set up notifications**: [Notifications Guide](guides/NOTIFICATIONS.md)
2. **Customize severity**: [Customization Guide](CUSTOMIZATION.md)
3. **Enable advanced features**: [Baseline Monitoring](features/BASELINE_MONITORING.md)
4. **Build integrations**: [Plugin System](PLUGIN_SYSTEM.md)

## Troubleshooting

### "No errors showing up"

**Check**:
1. Errors are being logged: `rails console` → `raise "test"`
2. Database migration ran: `rails db:migrate:status | grep error_dashboard`
3. Middleware is active: Check `config/application.rb`

**Fix**:
```bash
# Re-run migrations
rails rails_error_dashboard:install:migrations
rails db:migrate
```

### "Dashboard returns 404"

**Check routes**:
```bash
rails routes | grep error
```

**Should see**:
```
Rails.application.routes.draw do
  mount RailsErrorDashboard::Engine => "/error_dashboard"
end
```

### "Authentication not working"

**Verify credentials** in `config/initializers/rails_error_dashboard.rb`:
```ruby
config.username = "admin"
config.password = "your_password"
```

**Restart server** after changing configuration:
```bash
rails server
```

### "Errors not capturing automatically"

**Check middleware is installed**:

```ruby
# config/application.rb
config.middleware.use RailsErrorDashboard::Middleware::ErrorCatcher
```

**Or install manually**:
```bash
rails generate rails_error_dashboard:install
```

## Performance Tips

### Use Async Logging

For production apps, enable async logging:

```ruby
config.async_logging = true
config.async_adapter = :sidekiq
```

**With Sidekiq**:
```ruby
# Gemfile
gem 'sidekiq'

# config/initializers/rails_error_dashboard.rb
config.async_adapter = :sidekiq
```

**With SolidQueue**:
```ruby
# Gemfile
gem 'solid_queue'

# config/initializers/rails_error_dashboard.rb
config.async_adapter = :solid_queue
```

### Limit Backtrace Size

Large backtraces slow down the database:

```ruby
config.max_backtrace_lines = 50  # Default, good for most cases
config.max_backtrace_lines = 20  # Smaller for high-volume apps
```

### Sample Errors

For apps with >1000 errors/day:

```ruby
config.sampling_rate = 0.1  # Log 10% of errors
```

## Production Checklist

Before deploying to production:

- [ ] Change default username and password
- [ ] Enable async logging (`async_logging = true`)
- [ ] Set up notifications (Slack, Email, PagerDuty)
- [ ] Configure custom severity rules
- [ ] Set backtrace limit (`max_backtrace_lines`)
- [ ] Consider sampling for high-traffic apps
- [ ] Test error notifications
- [ ] Set up database backups
- [ ] Configure data retention (delete old errors)

## Getting Help

- **Documentation**: [docs/README.md](README.md)
- **Issues**: [GitHub Issues](https://github.com/yourusername/rails_error_dashboard/issues)
- **Configuration**: [Configuration Guide](guides/CONFIGURATION.md)

## What's Next?

Explore advanced features:

- **[Baseline Monitoring](features/BASELINE_MONITORING.md)** - Proactive anomaly detection
- **[Platform Comparison](features/PLATFORM_COMPARISON.md)** - iOS vs Android health
- **[Error Correlation](features/ERROR_CORRELATION.md)** - Track errors by version
- **[Plugin System](PLUGIN_SYSTEM.md)** - Build custom integrations

---

**Congratulations!** Your error dashboard is now running. Start catching and resolving errors! 🎉
