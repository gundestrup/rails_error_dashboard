---
description: Audit roadmap progress — cross-reference ROADMAP.md with actual codebase implementation
user-invocable: true
disable-model-invocation: true
---

# /roadmap-status — Roadmap Progress Audit

Read ROADMAP.md and cross-reference each item against the actual codebase to determine what's done vs not done.

## Steps

1. **Read the roadmap**:
   Read `ROADMAP.md` in the project root.

2. **For each roadmap item**, check if it's implemented by searching the codebase:
   - Look for relevant files in `lib/rails_error_dashboard/`, `app/`, `config/`
   - Check for specs in `spec/`
   - Check CHANGELOG.md for release notes mentioning the feature
   - Look for config options in `lib/rails_error_dashboard/configuration.rb`

3. **Build a status table** with columns:
   | Status | Version | Feature | Evidence |
   |--------|---------|---------|----------|
   | DONE | v0.2.0 | Cause chain extraction | `services/cause_chain_extractor.rb` |
   | DONE | v0.3.0 | Flexible auth | `configuration.rb:authenticate_with` |
   | NOT DONE | v0.4.0 | Breadcrumb capture | No `breadcrumb_subscriber.rb` found |
   | PARTIAL | v0.5.0 | TracePoint locals | Config option exists but no implementation |

4. **Summarize**:
   - Total items done / total items
   - Next milestone items remaining
   - Any items marked as done in ROADMAP but not actually implemented (or vice versa)

## Output Format

Print the table in markdown format, grouped by version milestone. Add a summary section at the end.

## Key Files to Check

- `ROADMAP.md` — the roadmap itself
- `CHANGELOG.md` — what's been released
- `lib/rails_error_dashboard/version.rb` — current version
- `lib/rails_error_dashboard/configuration.rb` — config options (100+)
- `lib/rails_error_dashboard/commands/` — write operations
- `lib/rails_error_dashboard/queries/` — read operations
- `lib/rails_error_dashboard/services/` — algorithms
- `config/routes.rb` — dashboard endpoints
