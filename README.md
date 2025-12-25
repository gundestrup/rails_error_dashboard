# Rails Error Dashboard

[![Gem Version](https://badge.fury.io/rb/rails_error_dashboard.svg)](https://badge.fury.io/rb/rails_error_dashboard)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/AnjanJ/rails_error_dashboard/workflows/Tests/badge.svg)](https://github.com/AnjanJ/rails_error_dashboard/actions)

## Self-hosted Rails error monitoring — free, forever.

**Own your errors. Own your stack. Zero monthly fees.**

A fully open-source, self-hosted error dashboard for solo founders, indie hackers, and small teams who want complete control without the SaaS bills.

```ruby
gem 'rails_error_dashboard'
```

**5-minute setup** · **Works out-of-the-box** · **100% Rails + Postgres** · **No vendor lock-in**

---

### ⚠️ BETA SOFTWARE
This Rails Engine is in beta and under active development. While functional and tested (850+ tests passing), the API may change before v1.0.0. Use in production at your own discretion.

**Supports**: Rails 7.0 - 8.1 | Ruby 3.2+

---

## 🎯 Who This Is For

✓ **Solo bootstrappers** who need professional error tracking without recurring costs

✓ **Indie SaaS founders** building profitable apps on tight budgets

✓ **Small dev teams** (2-5 people) who hate SaaS bloat

✓ **Privacy-conscious apps** that need to keep error data on their own servers

✓ **Side projects** that might become real businesses

---

## 💰 What It Replaces

| Before | After |
|--------|-------|
| Pay $29-99/month for error monitoring | $0/month - runs on your existing Rails server |
| Send sensitive error data to third parties | Keep all data on your infrastructure |
| Fight with SaaS pricing tiers and limits | Unlimited errors, unlimited projects |
| Vendor lock-in with proprietary APIs | 100% open source, fully portable |
| Complex setup with SDKs and external services | 5-minute Rails Engine installation |

---

## 🚀 Why Choose Rails Error Dashboard

**"Install once, own it forever"**

- ✅ **Zero recurring costs** - One-time setup, runs on your existing infrastructure
- ✅ **5-minute installation** - Mount the Rails Engine, run migrations, done
- ✅ **Works immediately** - Automatic error capture from Rails controllers, jobs, models
- ✅ **Beautiful UI** - Professional dashboard you can show to clients
- ✅ **Full control** - Your data stays on your server, modify anything you want
- ✅ **No surprises** - Open source MIT license, no hidden fees or limits

**Built for developers who:**
- Want professional error monitoring without the SaaS tax
- Need to debug production issues without paying per error
- Value data privacy and server ownership
- Prefer simple, Rails-native solutions

---

![Dashboard Screenshot](https://via.placeholder.com/800x400?text=Error+Dashboard+Screenshot)

---

## ✨ Features

### 🎯 Complete Error Tracking
Automatic error capture from Rails controllers, jobs, and middleware. Frontend & mobile support for React, React Native, Vue, Angular, Flutter. Platform detection (iOS/Android/Web/API), user context tracking, full stack traces.

### 📊 Beautiful Dashboard
Modern Bootstrap 5 UI with dark/light mode, responsive design, real-time statistics, search and filtering, fast pagination.

### 📈 Analytics & Insights
7-day trend charts, severity breakdown, spike detection, platform comparison, resolution rate tracking, user impact analysis.

### 🚨 Multi-Channel Alerting
Slack, Email, Discord, PagerDuty, and custom webhooks. Beautifully formatted messages with rich context, direct links to errors, customizable per channel.

### ⚡ Performance & Scalability
Async error logging, backtrace limiting (70-90% storage reduction), error sampling, database optimization with composite indexes, PostgreSQL GIN indexes.

### 🔌 Plugin System
Extensible architecture with event hooks. Built-in examples for Jira, metrics tracking, audit logging. Easy to create custom integrations.

### 🔒 Security & Privacy
HTTP Basic Auth, environment-based settings, optional separate database for isolation.

**📚 [View complete feature list →](docs/FEATURES.md)**

---

## 📦 Quick Start

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

This will:
- Create `config/initializers/rails_error_dashboard.rb`
- Copy database migrations
- Mount the engine at `/error_dashboard`

### 3. Visit your dashboard

Start your server and visit:
```
http://localhost:3000/error_dashboard
```

**Default credentials:**
- Username: `gandalf`
- Password: `youshallnotpass`

⚠️ **Change these before production!** Edit `config/initializers/rails_error_dashboard.rb`

### 4. Test it out

Trigger a test error to see it in action:

```ruby
# In Rails console or any controller
raise "Test error from Rails Error Dashboard!"
```

The error will appear instantly in your dashboard with full context, backtrace, and platform information.

**📘 [Full installation guide →](docs/QUICKSTART.md)**

---

## ⚙️ Configuration

### Basic Setup

Edit `config/initializers/rails_error_dashboard.rb`:

```ruby
RailsErrorDashboard.configure do |config|
  # Dashboard authentication
  config.dashboard_username = ENV.fetch('ERROR_DASHBOARD_USER', 'gandalf')
  config.dashboard_password = ENV.fetch('ERROR_DASHBOARD_PASSWORD', 'youshallnotpass')

  # Slack notifications
  config.enable_slack_notifications = true
  config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']

  # Email notifications
  config.enable_email_notifications = true
  config.notification_email_recipients = ["dev@yourapp.com"]
  config.notification_email_from = "errors@yourapp.com"
end
```

### Environment Variables

```bash
# .env
ERROR_DASHBOARD_USER=your_username
ERROR_DASHBOARD_PASSWORD=your_secure_password
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
DASHBOARD_BASE_URL=https://yourapp.com
```

**📖 [Complete configuration guide →](docs/guides/CONFIGURATION.md)**

---

## 🚀 Usage

### Automatic Error Tracking

Rails Error Dashboard automatically tracks errors from:
- **Controllers** (via Rails error reporting)
- **Background jobs** (ActiveJob, Sidekiq)
- **Rack middleware** (catches everything else)

No additional code needed! Just install and it works.

### Manual Error Logging

For frontend/mobile apps or custom error logging:

```ruby
# From your Rails API
RailsErrorDashboard::Commands::LogError.call(
  error_type: "TypeError",
  message: "Cannot read property 'name' of null",
  backtrace: ["App.js:42", "index.js:12"],
  platform: "iOS",
  app_version: "2.1.0",
  user_id: current_user.id,
  context: {
    component: "ProfileScreen",
    device_model: "iPhone 14 Pro"
  }
)
```

### Frontend Integration

```javascript
// React Native example
try {
  // Your code
} catch (error) {
  fetch('https://yourapp.com/api/errors', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      error_type: error.name,
      message: error.message,
      backtrace: error.stack.split('\n'),
      platform: Platform.OS, // 'ios' or 'android'
      app_version: VERSION
    })
  });
}
```

**📱 [Mobile app integration guide →](docs/guides/MOBILE_APP_INTEGRATION.md)**

---

## 🔔 Notifications

Set up multi-channel notifications in minutes:

### Slack
```ruby
config.enable_slack_notifications = true
config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
```

### Discord
```ruby
config.enable_discord_notifications = true
config.discord_webhook_url = ENV['DISCORD_WEBHOOK_URL']
```

### PagerDuty (Critical Errors Only)
```ruby
config.enable_pagerduty_notifications = true
config.pagerduty_integration_key = ENV['PAGERDUTY_INTEGRATION_KEY']
```

### Custom Webhooks
```ruby
config.enable_webhook_notifications = true
config.webhook_urls = ['https://yourapp.com/hooks/errors']
```

**🔕 [Notification setup guide →](docs/guides/NOTIFICATIONS.md)**

---

## 📚 Documentation

### Getting Started
- **[Quickstart Guide](docs/QUICKSTART.md)** - Complete 5-minute setup
- **[Configuration](docs/guides/CONFIGURATION.md)** - All configuration options
- **[Mobile App Integration](docs/guides/MOBILE_APP_INTEGRATION.md)** - React Native, Flutter, etc.

### Features
- **[Complete Feature List](docs/FEATURES.md)** - Every feature explained
- **[Notifications](docs/guides/NOTIFICATIONS.md)** - Multi-channel alerting
- **[Batch Operations](docs/guides/BATCH_OPERATIONS.md)** - Bulk resolve/delete
- **[Real-Time Updates](docs/guides/REAL_TIME_UPDATES.md)** - Live dashboard
- **[Error Trend Visualizations](docs/guides/ERROR_TREND_VISUALIZATIONS.md)** - Charts & analytics

### Advanced
- **[Plugin System](docs/PLUGIN_SYSTEM.md)** - Build custom integrations
- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation
- **[Customization Guide](docs/CUSTOMIZATION.md)** - Customize everything
- **[Database Options](docs/guides/DATABASE_OPTIONS.md)** - Separate database setup
- **[Database Optimization](docs/guides/DATABASE_OPTIMIZATION.md)** - Performance tuning

### Development
- **[Testing](docs/development/TESTING.md)** - Multi-version testing
- **[CI Setup](docs/development/CI_SETUP.md)** - GitHub Actions configuration

**📖 [View all documentation →](docs/README.md)**

---

## 🏗️ Architecture

Built with **Service Objects + CQRS Principles**:
- **Commands**: LogError, ResolveError, BatchOperations (write operations)
- **Queries**: ErrorsList, DashboardStats, Analytics (read operations)
- **Value Objects**: ErrorContext (immutable data)
- **Services**: PlatformDetector, SimilarityCalculator (business logic)
- **Plugins**: Event-driven extensibility

Clean, maintainable, testable architecture you can understand and modify.

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/AnjanJ/rails_error_dashboard.git
cd rails_error_dashboard
bundle install

# Run tests
bundle exec rspec

# Run tests for all Rails versions
bundle exec appraisal rspec
```

**🔧 [Development guide →](docs/development/TESTING.md)**

---

## 📝 License

Rails Error Dashboard is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

## 🙏 Acknowledgments

- Built with [Rails](https://rubyonrails.org/)
- UI powered by [Bootstrap 5](https://getbootstrap.com/)
- Charts by [Chart.js](https://www.chartjs.org/)
- Pagination by [Pagy](https://github.com/ddnexus/pagy)
- Platform detection by [Browser gem](https://github.com/fnando/browser)

---

## 💬 Support

- **📖 Documentation**: [docs/](docs/README.md)
- **🐛 Issues**: [GitHub Issues](https://github.com/AnjanJ/rails_error_dashboard/issues)
- **💡 Discussions**: [GitHub Discussions](https://github.com/AnjanJ/rails_error_dashboard/discussions)

---

**Made with ❤️ by Anjan for the Rails community**

*One Gem to rule them all, One Gem to find them, One Gem to bring them all, and in the dashboard bind them.* 🧙‍♂️
