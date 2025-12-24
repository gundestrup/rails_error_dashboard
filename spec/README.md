# Rails Error Dashboard - Test Suite

Comprehensive test coverage for the Rails Error Dashboard gem using RSpec.

## Setup

```bash
bundle install
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/commands/log_error_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

## Test Structure

```
spec/
├── commands/           # Command objects (LogError, ResolveError)
├── queries/            # Query objects (ErrorsList, DashboardStats, etc.)
├── services/           # Service objects (PlatformDetector)
├── value_objects/      # Value objects (ErrorContext)
├── models/             # ActiveRecord models
├── controllers/        # Controller tests
├── jobs/               # Background job tests
├── mailers/            # Mailer tests
├── factories/          # FactoryBot factories
├── support/            # Test support files
└── vcr_cassettes/      # VCR cassettes for HTTP requests
```

## Test Coverage

The test suite covers:

- ✅ **Commands**: LogError, ResolveError
- ✅ **Services**: PlatformDetector
- ✅ **Value Objects**: ErrorContext
- ✅ **Models**: ErrorLog with validations and scopes
- ✅ **Integration**: Error logging flow, notifications, platform detection

### Coverage Goals

- Minimum coverage: **80%**
- Current coverage: Run `bundle exec rspec` to see latest

## Tools Used

- **RSpec** - Testing framework
- **FactoryBot** - Test data generation
- **Faker** - Fake data generation
- **DatabaseCleaner** - Database cleanup between tests
- **WebMock** - HTTP request stubbing
- **VCR** - Record and replay HTTP interactions
- **SimpleCov** - Code coverage reporting

## Writing Tests

### Example Command Test

```ruby
RSpec.describe RailsErrorDashboard::Commands::LogError do
  describe '.call' do
    let(:exception) { StandardError.new('Test error') }
    let(:context) { { current_user: user } }

    it 'creates an error log' do
      expect {
        described_class.call(exception, context)
      }.to change(RailsErrorDashboard::ErrorLog, :count).by(1)
    end
  end
end
```

### Using Factories

```ruby
# Create a basic error log
error_log = create(:error_log)

# Create with traits
ios_error = create(:error_log, :ios, :resolved)
android_error = create(:error_log, :android, :production)
api_error = create(:error_log, :api, :with_user)
```

## Best Practices

1. **Use factories** instead of creating records manually
2. **Use let/let!** for test data setup
3. **Test one thing** per example
4. **Use descriptive names** for context and it blocks
5. **Clean up** after tests (DatabaseCleaner handles this)
6. **Mock external services** with WebMock/VCR
7. **Test edge cases** and error conditions
8. **Maintain fast tests** - avoid unnecessary database hits

## Continuous Integration

Tests run on every commit via GitHub Actions (when configured).

---

**Made with ❤️ by Anjan for the Rails community**
