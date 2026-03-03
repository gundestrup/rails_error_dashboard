---
description: Run RSpec tests — full suite, quick, system, or specific files
user-invocable: true
disable-model-invocation: true
---

# /test — Run RSpec Tests

Run the RSpec test suite with various scopes.

## Usage

- `/test` or `/test all` — full suite (~1895 specs, ~37s)
- `/test quick` — skip system tests (faster)
- `/test system` — system tests only (Capybara + Cuprite, headless Chrome)
- `/test system visible` — system tests with visible browser (`HEADLESS=false`)
- `/test <path>` — specific file or directory (e.g., `/test spec/queries/`)

## Commands

### Full Suite
```bash
bundle exec rspec
```

### Quick (Skip System Tests)
```bash
bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"
```

### System Tests
```bash
bundle exec rspec spec/system/
```

### Visible Browser
```bash
HEADLESS=false bundle exec rspec spec/system/
```

### With Inspector (Chrome DevTools)
```bash
INSPECTOR=true HEADLESS=false bundle exec rspec spec/system/
```

### Specific File
```bash
bundle exec rspec spec/queries/rails_error_dashboard/errors_list_spec.rb
```

## After Running

- Report the result summary (examples, failures, pending)
- If failures occur, read the failure output and suggest fixes
- If all pass, report the count and time

## Test Organization

```
spec/
├── commands/          # Command specs (writes)
├── queries/           # Query specs (reads)
├── services/          # Service specs (algorithms)
├── models/            # Model specs
├── jobs/              # Job specs
├── helpers/           # Helper specs
├── generators/        # Generator specs
├── integration/       # Cross-layer tests
├── system/            # Capybara browser tests (6 specs)
├── support/           # Shared helpers, factories, config
└── dummy/             # Test Rails app
```

## Notes

- System tests use Cuprite (Chrome DevTools Protocol, not Selenium)
- WebMock allows CDN requests in system specs only
- Auth in system tests: URL-embedded HTTP Basic Auth via `visit_dashboard` helper
- Ruby 4.0.1: `ostruct` removed from default gems — test factory uses `Struct` instead
