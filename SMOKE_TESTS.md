# Deployment Smoke Tests

This directory contains automated smoke tests to verify that a Rails Error Dashboard deployment is working correctly.

## What Are Smoke Tests?

Smoke tests are a type of basic integration test that verify the fundamental functionality of a deployed application. These tests make HTTP requests to key pages and verify:

- Pages return expected HTTP status codes
- Pages contain expected content
- No server errors are present in responses
- Authentication is working correctly
- Key features are accessible

## Quick Start

Test your deployment:

```bash
./bin/smoke-test https://your-dashboard-url.com username password
```

Example:

```bash
./bin/smoke-test https://rails-error-dashboard.anjan.dev frodo precious
```

## Test Coverage

The smoke test suite covers:

### Authentication (1 test)
- ✅ Unauthenticated requests properly blocked (HTTP 401)

### Core Pages (5 tests)
- ✅ Dashboard overview
- ✅ Error list page
- ✅ Analytics page
- ✅ Platform comparison page
- ✅ Error correlation page

### Filtering (4 tests)
- ✅ Unresolved errors filter
- ✅ Critical priority filter
- ✅ iOS platform filter
- ✅ Web platform filter

### Detail Pages (1 test)
- ✅ Individual error detail page

### Pagination (2 tests)
- ✅ Page 1
- ✅ Page 2

### Assets (2 tests)
- ✅ Bootstrap CSS referenced
- ✅ Chart.js/Chartkick referenced

**Total: 15 automated tests**

## Usage

### Command Line Arguments

```bash
./bin/smoke-test [URL] [USERNAME] [PASSWORD]
```

### Environment Variables

Alternatively, set environment variables:

```bash
export DASHBOARD_URL=https://example.com
export DASHBOARD_USER=admin
export DASHBOARD_PASSWORD=secret
./bin/smoke-test
```

### Exit Codes

- `0` - All tests passed ✅
- `1` - One or more tests failed ❌

## Output Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Rails Error Dashboard - Deployment Smoke Tests
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Testing: https://rails-error-dashboard.anjan.dev
User: frodo

Running authentication tests...

Test  1: Unauthenticated access blocked                     PASS (Correctly requires auth)

Running core page tests...

Test  2: Dashboard overview page                            PASS (53273 bytes)
Test  3: Error list page                                    PASS (94170 bytes)
Test  4: Analytics page                                     PASS (83736 bytes)
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Test Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Tests:  15
Passed:       15
Failed:       0

✅ All tests passed!
```

## Use Cases

### After Each Deployment

Run smoke tests after deploying to verify the deployment succeeded:

```bash
# Deploy your app
git push production main

# Wait for deployment to complete, then test
./bin/smoke-test https://your-app.com admin secret
```

### Before Each Release

Add to your release checklist:

```bash
# Before releasing v0.2.0
./bin/smoke-test https://demo.example.com user pass
gem build rails_error_dashboard.gemspec
gem push rails_error_dashboard-0.2.0.gem
```

### CI/CD Pipeline

Run automatically in GitHub Actions, GitLab CI, or your CI/CD tool of choice:

```yaml
# See .github/workflows/smoke-test-demo.yml for example
```

### Monitoring

Run periodically to monitor your production deployment:

```bash
# Add to cron for hourly checks
0 * * * * cd /path/to/rails_error_dashboard && ./bin/smoke-test https://your-app.com user pass || notify_team
```

## What Gets Tested

### Response Validation

Each test verifies:

1. **HTTP Status Code** - Must match expected (usually 200)
2. **Response Size** - Must exceed minimum threshold (prevents empty responses)
3. **No Server Errors** - Checks for "500 Internal Server Error", "The Error Dashboard encountered an issue", pagination errors
4. **Expected Content** - Verifies key terms are present (optional per test)

### Critical Verifications

The test suite specifically checks for:

- ✅ **Pagination bug fixed** - No `undefined method 'pagy_bootstrap_nav'` errors
- ✅ **Authentication working** - Unauthorized users blocked
- ✅ **Database seeded** - Error detail page finds at least one error
- ✅ **Charts loading** - Chart.js and Chartkick scripts referenced
- ✅ **Bootstrap UI** - CSS framework properly loaded

## Limitations

These are **smoke tests**, not comprehensive integration tests. They verify:

- ✅ Pages load without errors
- ✅ Expected content is present
- ✅ Authentication is enforced

They do **NOT** verify:

- ❌ JavaScript functionality
- ❌ Form submissions
- ❌ Action execution (resolve, assign, etc.)
- ❌ Real-time updates
- ❌ Notification integrations
- ❌ Visual regression

For comprehensive testing, use RSpec integration tests in the `spec/` directory.

## Troubleshooting

### Test Fails: "HTTP 000"

**Cause**: Network error, DNS resolution failure, or connection refused

**Solutions**:
- Verify URL is correct and accessible
- Check if deployment is running
- Verify network connectivity

### Test Fails: "Server error detected"

**Cause**: Application returned 500 error or Rails error page

**Solutions**:
- Check application logs for errors
- Verify database migrations ran successfully
- Ensure environment variables are set correctly

### Test Fails: "Response too small"

**Cause**: Page returned but content is incomplete

**Solutions**:
- Check for asset compilation errors
- Verify database has seed data
- Check application logs for template errors

### Test Fails: "Missing expected content"

**Cause**: Page loaded but doesn't contain expected text

**Solutions**:
- Feature may be disabled in configuration
- Database may be empty
- Template may have changed

## Adding New Tests

To add a new smoke test:

1. Add a new `run_test` call in the appropriate section
2. Specify: test name, URL path, expected status, search term (optional), min size
3. Update this README with the new test

Example:

```bash
run_test "New feature page" "/error_dashboard/new_feature" 200 "Feature Name" 10000
```

## Related Documentation

- [Main README](README.md) - Gem documentation
- [Contributing Guide](CONTRIBUTING.md) - Development guidelines
- [RSpec Tests](spec/) - Comprehensive test suite

## Questions?

Open an issue at: https://github.com/AnjanJ/rails_error_dashboard/issues
