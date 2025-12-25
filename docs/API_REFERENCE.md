# API Reference

Complete API documentation for Rails Error Dashboard.

## Configuration API

### RailsErrorDashboard.configure

```ruby
RailsErrorDashboard.configure do |config|
  # See CUSTOMIZATION.md for all options
end
```

## Commands API

### LogError

Log an error to the dashboard.

```ruby
RailsErrorDashboard::Commands::LogError.call(
  error_type: "NoMethodError",
  message: "undefined method 'name' for nil:NilClass",
  backtrace: exception.backtrace,
  occurred_at: Time.current,
  platform: "iOS",  # or "Android", "API", "Web"
  app_version: "2.1.0",
  git_sha: "a3b4c5d6",
  user_id: 123,
  request_url: "/api/users",
  request_params: { id: 1 },
  ip_address: "192.168.1.1",
  user_agent: "Mozilla/5.0..."
)
```

### ResolveError

Mark an error as resolved.

```ruby
RailsErrorDashboard::Commands::ResolveError.call(
  error_id: 123,
  resolved_by: "developer@example.com",
  resolution_comment: "Fixed in PR #456",
  resolution_reference: "https://github.com/org/repo/pull/456"
)
```

### BatchDeleteErrors

Delete multiple errors.

```ruby
RailsErrorDashboard::Commands::BatchDeleteErrors.call(
  error_ids: [1, 2, 3, 4, 5]
)
```

## Query Objects API

### DashboardStats

```ruby
stats = RailsErrorDashboard::Queries::DashboardStats.call

stats[:total_errors]          # Total error count
stats[:errors_today]          # Errors today
stats[:errors_last_7_days]    # Last 7 days
stats[:errors_last_30_days]   # Last 30 days
stats[:top_errors]            # Top 10 error types
stats[:errors_by_platform]    # Grouped by platform
stats[:resolved_count]        # Resolved errors
stats[:unresolved_count]      # Unresolved errors
```

### ErrorsList

```ruby
errors = RailsErrorDashboard::Queries::ErrorsList.call(
  platform: "iOS",
  error_type: "NoMethodError",
  unresolved: true,
  search: "payment"
)
```

### SimilarErrors

```ruby
similar = RailsErrorDashboard::Queries::SimilarErrors.call(
  error_id: 123,
  threshold: 0.6,  # 60% similarity
  limit: 10
)

similar.each do |result|
  result[:error]       # ErrorLog instance
  result[:similarity]  # 0.0 - 1.0
end
```

### PlatformComparison

```ruby
comparison = RailsErrorDashboard::Queries::PlatformComparison.new(days: 7)

comparison.error_rate_by_platform
comparison.platform_stability_scores
comparison.platform_health_summary("iOS")
comparison.cross_platform_errors
```

### ErrorCorrelation

```ruby
correlation = RailsErrorDashboard::Queries::ErrorCorrelation.new(days: 30)

correlation.errors_by_version
correlation.problematic_releases
correlation.multi_error_users
correlation.time_correlated_errors
```

## Models API

### ErrorLog

```ruby
error = RailsErrorDashboard::ErrorLog.find(123)

# Attributes
error.error_type       # "NoMethodError"
error.message          # Error message
error.backtrace        # Stack trace
error.platform         # "iOS", "Android", etc.
error.app_version      # "2.1.0"
error.occurrence_count # How many times occurred
error.resolved?        # Boolean
error.severity         # :critical, :high, :medium, :low

# Associations
error.similar_errors(threshold: 0.6)
error.co_occurring_errors(window_minutes: 5)
error.error_cascades(min_probability: 0.5)
error.occurrence_pattern(days: 30)
error.error_bursts(days: 7)
```

## Service Objects API

### PatternDetector

```ruby
# Cyclical patterns
pattern = RailsErrorDashboard::Services::PatternDetector.analyze_cyclical_pattern(
  error_type: "NoMethodError",
  platform: "iOS",
  days: 30
)

pattern[:pattern_type]        # :business_hours, :night, :weekend, :uniform
pattern[:pattern_strength]    # 0.0 - 1.0
pattern[:peak_hours]          # [9, 10, 11, 14, 15]
pattern[:hourly_distribution] # { 0 => 5, 1 => 3, ... }

# Bursts
bursts = RailsErrorDashboard::Services::PatternDetector.detect_bursts(
  error_type: "NoMethodError",
  platform: "iOS",
  days: 7
)
```

### CascadeDetector

```ruby
result = RailsErrorDashboard::Services::CascadeDetector.call(
  lookback_hours: 24
)

result[:detected]  # Number of new cascades
result[:updated]   # Number of updated cascades
```

### BaselineCalculator

```ruby
RailsErrorDashboard::Services::BaselineCalculator.calculate_all_baselines
```

## Complete Reference

For more details, see the source code or inline documentation (YARD format).

**Models**: `app/models/rails_error_dashboard/`
**Commands**: `lib/rails_error_dashboard/commands/`
**Queries**: `lib/rails_error_dashboard/queries/`
**Services**: `lib/rails_error_dashboard/services/`
