# Exception Handling Plan

**Goal**: Ensure the Rails Error Dashboard gem NEVER breaks the main application under any circumstances.

## Critical Principle

**The gem must fail silently and gracefully.** Any exception within the gem should be logged but never propagated to the main application.

---

## Failure Points Analysis

### 🔴 CRITICAL PATH (Must Never Fail - App Breaking)

These components run on every request or error. If they fail, they break the app.

#### 1. Middleware (`lib/rails_error_dashboard/middleware/error_catcher.rb`)
**Risk**: Runs on EVERY request. Exception here breaks the entire app.
**Current State**: Has rescue block but may not catch all edge cases
**Fix Needed**:
- Top-level rescue block catching ALL exceptions
- Log to Rails.logger with full context
- Never re-raise
- Return response gracefully

#### 2. Error Subscriber (`lib/rails_error_dashboard/error_subscriber.rb`)
**Risk**: Called by Rails.error on every error. Exception here could cause cascading failures.
**Current State**: Needs audit
**Fix Needed**:
- Wrap entire subscribe block in rescue
- Log failures to Rails.logger
- Never re-raise

#### 3. LogError Command (`lib/rails_error_dashboard/commands/log_error.rb`)
**Risk**: Called by middleware and subscriber. Exception here stops error logging.
**Current State**: Has rescue at line 112, but may not cover all paths
**Fix Needed**:
- Ensure all database operations are wrapped
- Catch exceptions from: find_or_increment_by_hash, ErrorOccurrence.create, notification dispatch
- Safe navigation for all context access

---

### 🟡 HIGH PRIORITY (Should Handle Gracefully)

These run frequently and should never cause issues.

#### 4. All Background Jobs
**Files**:
- `app/jobs/rails_error_dashboard/async_error_logging_job.rb`
- `app/jobs/rails_error_dashboard/slack_error_notification_job.rb`
- `app/jobs/rails_error_dashboard/email_error_notification_job.rb`
- `app/jobs/rails_error_dashboard/discord_error_notification_job.rb`
- `app/jobs/rails_error_dashboard/pagerduty_error_notification_job.rb`
- `app/jobs/rails_error_dashboard/webhook_error_notification_job.rb`
- `app/jobs/rails_error_dashboard/baseline_calculation_job.rb`
- `app/jobs/rails_error_dashboard/cascade_detection_job.rb`
- `app/jobs/rails_error_dashboard/baseline_alert_job.rb`

**Risk**: Job failures can spam error logs or break job queues
**Fix Needed**:
- Rescue StandardError in perform method
- Log failures with context
- Use retries judiciously (max 3)
- Add timeouts for external HTTP calls

#### 5. Controllers (`app/controllers/rails_error_dashboard/`)
**Files**:
- `application_controller.rb`
- `errors_controller.rb`

**Risk**: Exception in controller breaks dashboard UI
**Current State**: No rescue_from
**Fix Needed**:
- Add rescue_from StandardError in ApplicationController
- Render user-friendly error page
- Log exception details

#### 6. External HTTP Calls
**Locations**:
- Slack notifications (HTTParty)
- Discord notifications (HTTParty)
- PagerDuty notifications (HTTParty)
- Webhook notifications (HTTParty)

**Risk**: Timeout, connection errors, DNS failures
**Fix Needed**:
- Add timeout: 5 seconds to all HTTParty calls
- Rescue HTTParty::Error, Timeout::Error, SocketError
- Log failures, don't propagate

---

### 🟢 MEDIUM PRIORITY (Should Be Safe)

#### 7. Query Objects (`lib/rails_error_dashboard/queries/`)
**Risk**: Bad SQL, missing data, type errors
**Fix Needed**:
- Use find_by instead of find
- Safe navigation for associations
- Default values for calculations (e.g., || 0)
- Rescue ActiveRecord::StatementInvalid

#### 8. Service Objects (`lib/rails_error_dashboard/services/`)
**Risk**: Calculation errors, nil references
**Fix Needed**:
- Input validation
- Safe navigation
- Rescue specific exceptions

#### 9. Plugin System (`lib/rails_error_dashboard/plugin_registry.rb`)
**Risk**: User-defined plugins could raise exceptions
**Current State**: Has rescue at line 30
**Fix Needed**:
- Ensure rescue catches all exceptions in plugin dispatch
- Log plugin failures clearly
- Continue dispatching to other plugins

#### 10. Notification Callbacks
**Location**: Configuration callbacks in `commands/log_error.rb`
**Current State**: Has rescue at lines 126, 135
**Fix Needed**:
- Verify rescue blocks catch all exceptions
- Log which callback failed

---

## Implementation Strategy

### Phase 1: Critical Path (MUST DO)
1. ✅ Audit and fix middleware
2. ✅ Audit and fix error subscriber
3. ✅ Audit and fix LogError command
4. ✅ Add comprehensive tests for failure scenarios

### Phase 2: High Priority
5. ✅ Add exception handling to all jobs
6. ✅ Add rescue_from to controllers
7. ✅ Add timeouts and rescues to HTTP calls
8. ✅ Test job failures

### Phase 3: Medium Priority
9. ✅ Audit query objects for safety
10. ✅ Audit service objects for safety
11. ✅ Verify plugin system safety
12. ✅ Add view safety (presence checks)

### Phase 4: Testing & Verification
13. ✅ Write tests simulating failures
14. ✅ Test with deliberately failing webhooks
15. ✅ Test with database errors
16. ✅ Test with nil data

---

## Exception Handling Patterns

### Pattern 1: Critical Path (Never Raise)

```ruby
def call
  # ... main logic
rescue => e
  Rails.logger.error("[RailsErrorDashboard] Critical failure: #{e.class} - #{e.message}")
  Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
  nil # Return nil, never raise
end
```

### Pattern 2: Jobs (Retry with Limit)

```ruby
class SomeJob < ApplicationJob
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(error_log_id)
    # ... main logic
  rescue StandardError => e
    Rails.logger.error("[RailsErrorDashboard] Job failed: #{e.message}")
    raise # Re-raise to trigger retry mechanism
  end
end
```

### Pattern 3: External HTTP Calls (Timeout + Rescue)

```ruby
def send_notification
  HTTParty.post(
    url,
    body: payload.to_json,
    headers: headers,
    timeout: 5 # 5 second timeout
  )
rescue HTTParty::Error, Timeout::Error, SocketError, Errno::ECONNREFUSED => e
  Rails.logger.error("[RailsErrorDashboard] HTTP call failed: #{e.message}")
  nil # Don't propagate
end
```

### Pattern 4: Query Objects (Safe Defaults)

```ruby
def calculate_average
  errors = ErrorLog.where(conditions)
  return 0 if errors.empty?

  (errors.sum(:count) / errors.count.to_f).round(2)
rescue ActiveRecord::StatementInvalid => e
  Rails.logger.error("[RailsErrorDashboard] Query failed: #{e.message}")
  0 # Return safe default
end
```

### Pattern 5: Controllers (User-Friendly Error)

```ruby
class ApplicationController < ActionController::Base
  rescue_from StandardError do |exception|
    Rails.logger.error("[RailsErrorDashboard] Controller error: #{exception.message}")

    render plain: "Error Dashboard encountered an issue. Your application is unaffected.",
           status: :internal_server_error
  end
end
```

---

## Logging Standards

All exception logs should follow this format:

```ruby
Rails.logger.error("[RailsErrorDashboard] <Component> <Action> failed: #{e.class} - #{e.message}")
Rails.logger.error("Context: #{context_hash.inspect}") if context_hash.present?
Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
```

Example:
```ruby
Rails.logger.error("[RailsErrorDashboard] Middleware error capture failed: NoMethodError - undefined method 'user_id' for nil:NilClass")
Rails.logger.error("Context: {:request_path=>'/users', :method=>'GET'}")
Rails.logger.error("/path/to/file.rb:42:in `call'\n...")
```

---

## Testing Strategy

### Failure Scenarios to Test

1. **Database failures**
   - Database connection lost mid-operation
   - Table doesn't exist
   - Column doesn't exist
   - Invalid SQL

2. **External service failures**
   - Webhook timeout
   - Webhook returns 500
   - DNS resolution fails
   - Connection refused

3. **Data integrity issues**
   - Nil objects where expected
   - Missing associations
   - Invalid data types

4. **Plugin failures**
   - Plugin raises exception
   - Plugin returns invalid data

5. **Callback failures**
   - User callback raises exception
   - Callback returns invalid data

### Test Examples

```ruby
# Test middleware resilience
it "doesn't break app when error logging fails" do
  allow(RailsErrorDashboard::Commands::LogError).to receive(:call).and_raise(StandardError)

  get "/some_path"
  expect(response).to be_successful # App still works!
end

# Test job resilience
it "handles webhook failures gracefully" do
  allow(HTTParty).to receive(:post).and_raise(Timeout::Error)

  expect {
    SlackErrorNotificationJob.perform_now(error_log.id)
  }.not_to raise_error
end
```

---

## Success Criteria

✅ Main app NEVER breaks due to gem exception
✅ All failures logged with clear context
✅ Features fail silently and gracefully
✅ External calls have timeouts
✅ No infinite retry loops
✅ Tests cover failure scenarios
✅ Clear logging for debugging

---

## Files to Modify (Priority Order)

### Critical (Do First)
1. `lib/rails_error_dashboard/middleware/error_catcher.rb`
2. `lib/rails_error_dashboard/error_subscriber.rb`
3. `lib/rails_error_dashboard/commands/log_error.rb`

### High Priority
4. `app/controllers/rails_error_dashboard/application_controller.rb`
5. All 9 job files in `app/jobs/rails_error_dashboard/`

### Medium Priority
6. All query files in `lib/rails_error_dashboard/queries/`
7. All service files in `lib/rails_error_dashboard/services/`
8. `lib/rails_error_dashboard/plugin_registry.rb`

### Supporting
9. Model methods in `app/models/rails_error_dashboard/error_log.rb`
10. View helpers if any

---

**Total Files to Audit**: ~30 files
**Estimated Time**: 2-3 hours for thorough implementation and testing
