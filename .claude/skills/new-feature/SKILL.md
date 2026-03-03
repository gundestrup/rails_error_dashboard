---
description: Scaffold a new CQRS class (command, query, or service) with spec following project conventions
user-invocable: true
disable-model-invocation: true
---

# /new-feature — Scaffold CQRS Class + Spec

Create a new command, query, or service class following the project's CQRS conventions.

## Usage

- `/new-feature command LogSomething` — create a command
- `/new-feature query SomeStats` — create a query
- `/new-feature service SomeCalculator` — create a service

If no arguments provided, ask the user: "What type (command/query/service) and what name?"

## Scaffolding Rules

### 1. Determine the Layer

| Type | Directory | Purpose | Verb Style |
|------|-----------|---------|------------|
| command | `lib/rails_error_dashboard/commands/` | Write operations | Action verb (`LogError`, `ResolveError`) |
| query | `lib/rails_error_dashboard/queries/` | Read operations | Noun/adjective (`ErrorsList`, `DashboardStats`) |
| service | `lib/rails_error_dashboard/services/` | Pure algorithms | Algorithm name (`ErrorNormalizer`, `SimilarityCalculator`) |

### 2. Create the Class File

File name: `lib/rails_error_dashboard/<type>s/<snake_case_name>.rb`

Follow this pattern (read an existing file from the same directory for reference):
- Module: `RailsErrorDashboard::<Type>s::<ClassName>`
- Factory method: `def self.call(...)`
- Constructor: `def initialize(...)`
- Instance method: `def call`
- Commands: rescue errors, never raise in capture path
- Queries: return data, never mutate
- Services: pure computation, no DB access

### 3. Create the Spec File

Spec path: `spec/<type>s/rails_error_dashboard/<snake_case_name>_spec.rb`

Follow this pattern (read an existing spec from the same directory for reference):
- `RSpec.describe RailsErrorDashboard::<Type>s::<ClassName> do`
- Test `self.call` factory method
- Test main behavior
- Test edge cases (nil input, empty data, errors)
- Commands: test that errors are rescued (never raise)
- Queries: test filters, sorting, empty results
- Services: test computation accuracy, edge cases

### 4. Register if Needed

- If the class needs to be autoloaded, check if `lib/rails_error_dashboard.rb` needs an `autoload` entry
- If the class adds a dashboard feature, check if `config/routes.rb` needs a route
- If the class adds a config option, add it to `lib/rails_error_dashboard/configuration.rb`

## Before Creating

Always read at least one existing file from the target directory to match:
- Exact module nesting
- Code style (rails-omakase, array brackets with inner spaces)
- Error handling patterns
- ActiveSupport::Notifications instrumentation (commands)

## After Creating

1. Run the new spec to verify it passes:
   ```bash
   bundle exec rspec spec/<type>s/rails_error_dashboard/<snake_case_name>_spec.rb
   ```
2. Run RuboCop on the new files:
   ```bash
   bundle exec rubocop lib/rails_error_dashboard/<type>s/<snake_case_name>.rb spec/<type>s/rails_error_dashboard/<snake_case_name>_spec.rb
   ```
