---
description: Host app safety rules and performance budgets for rails_error_dashboard
user-invocable: false
---

# Host App Safety Knowledge Base

This gem runs INSIDE the host Rails app's process. Every line of code we write can break the host app. These rules are non-negotiable.

## The 10 Safety Rules

1. **Never raise in the error capture path** — rescue at every layer. If our error tracker raises while capturing an error, we've made the situation worse.
2. **Never block the request path** — all heavy work (notifications, analytics) must be async/background. The request thread must return ASAP.
3. **Budget every operation** — breadcrumb callback <0.01ms, health snapshot <1ms, total capture <5ms. Measure with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`.
4. **Clean up Thread.current** — always use `ensure` blocks. Puma reuses threads across keepalive connections (Puma #823).
5. **Always re-raise original exceptions** — Sentry #1173: swallowed Sidekiq exceptions prevented retries. After capture, always `raise` the original.
6. **Feature-detect before calling** — `defined?(Puma)`, `respond_to?(:stats)`. Never assume a server/library exists.
7. **Make everything disableable** — every request-path feature needs a config flag. Users must be able to turn off anything that causes problems.
8. **Never use ObjectSpace.each_object** — freezes all threads, grows heap. Use `GC.stat` instead for memory info.
9. **Never use Signal.trap** — breaks Puma/Sidekiq signal handling (USR1/USR2 reserved). Use rake tasks for diagnostics.
10. **Never store Binding objects** — prevents GC of entire call stack. Extract local variables immediately into plain data.

## Real-World Incidents

### Sentry #1173 — Swallowed Sidekiq Retries
Middleware captured exception but forgot to re-raise. Sidekiq treated failed jobs as successful. Retries never happened. Production data loss.

### Puma #823 — Thread-Local Leak Across Keepalive
Thread.current values leaked between requests on the same keepalive connection. Puma only cleaned thread-locals before new work assignment, not between requests.

### Coverband — TracePoint :line Was 2.5x Slower
Abandoned TracePoint :line in favor of Coverage API (1.08x vs 2.5x overhead). Never use :line in production by default.

### Ruby #18264 — TracePoint Memory Leak
`rb_tp_t` struct allocated with RUBY_TYPED_NEVER_FREE in Ruby 2.6-3.0. Repeatedly creating TracePoints caused unbounded RSS growth. Gate on Ruby >= 3.2.

### Rails AS::Notifications — Subscribers CAN Crash Requests
`iterate_guarding_exceptions` collects subscriber exceptions and RE-RAISES them. A buggy subscriber on `sql.active_record` crashes the SQL query's caller. Breadcrumb subscriber MUST have its own rescue.

### Rack Middleware Constant Mutation
Shared mutable headers hash in a constant grew unbounded across requests. Never use mutable constants for per-request data.

### Signal.trap — Last Writer Wins
Puma uses USR1 (phased restart), USR2 (full restart). Sidekiq Enterprise uses USR2. Signal.trap completely replaces previous handler — no chaining.

## Performance Budgets

| Operation | Budget | Where |
|-----------|--------|-------|
| Breadcrumb callback | <0.01ms | AS::Notifications subscriber |
| Health snapshot | <1ms | GC.stat + connection_pool + Thread.list |
| Total error capture | <5ms | Middleware + subscriber path |
| Notification dispatch | 0ms sync | Always async via ActiveJob |
| Pattern detection | <10ms | Background job only |
| Analytics queries | <100ms | Dashboard request, not capture path |

## Code Review Checklist

When reviewing changes to the capture path (`middleware/`, `error_subscriber.rb`, `commands/log_error.rb`, `commands/find_or_increment_error.rb`):

- [ ] Every public method has a rescue clause
- [ ] No `raise` statements (except re-raising the original)
- [ ] No blocking I/O (HTTP calls, file reads, external services)
- [ ] Thread.current cleaned in `ensure`
- [ ] No `ObjectSpace`, `Signal.trap`, or `Binding` storage
- [ ] Feature-gated with config check
- [ ] Performance measured and within budget

## Existing Known Issues

1. `dashboard_stats.rb:343` — `average_resolution_time` loads all records into memory (should use SQL SUM)
2. `pattern_detector.rb:64` — iterates errors in Ruby instead of SQL GROUP BY
3. `cascade_detector.rb:64` — nested query loops without LIMIT bounds

## Roadmap Risk Ratings

- **CRITICAL**: AS::Notifications subscribers (breadcrumbs), TracePoint :line (dual mode), Signal.trap (diagnostic dump)
- **HIGH**: TracePoint :raise, swallowed exception detection, retention DELETE
- **MEDIUM**: System health snapshot, auto-reopen race condition, background job health
- **LOW**: Flexible auth, BRIN index migration, GitHub issue creation
