---
description: Release rules, commit conventions, and issue etiquette for rails_error_dashboard
user-invocable: false
---

# Release & Contribution Rules

## CRITICAL: Never Release Without Approval

**NEVER** execute any of these commands without explicit user approval:
- `gem push` — publishes to RubyGems (irreversible for that version number)
- `git tag` — creates a version tag
- `git push origin <tag>` — pushes tag to remote
- `gh release create` — creates GitHub Release

Prepare everything (version bump, changelog, commit, push to main), then STOP and ask: "Ready to publish vX.Y.Z to RubyGems and create the GitHub release?"

## CRITICAL: Never Close GitHub Issues

Always let the issue reporter verify the fix and close it themselves. When a fix is merged:
1. Comment on the issue with thanks
2. Explain the root cause
3. Describe the fix and which version includes it
4. Ask them to reopen if the issue persists
5. Do NOT close the issue

## Commit Message Conventions

Use conventional commits style:
- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — maintenance, deps, version bumps
- `docs:` — documentation only
- `refactor:` — code restructuring without behavior change
- `test:` — adding or fixing tests
- `perf:` — performance improvement

Examples:
```
feat: add N+1 query detection breadcrumb page
fix: resolve SQLite BRIN index migration error
chore: bump version to 0.3.0
docs: add flexible authentication to changelog and README
test: add system specs for deprecation warnings page
refactor: extract notification throttling to service
```

## Version Numbering

Follows semantic versioning (SemVer):
- **Major** (1.0.0) — breaking changes, public API changes
- **Minor** (0.3.0) — new features, backwards-compatible
- **Patch** (0.3.1) — bug fixes only

Current version: defined in `lib/rails_error_dashboard/version.rb`

## Release Artifacts

A complete release produces:
1. Version bump commit on `main`
2. RubyGems package (`.gem` file)
3. Git tag (`vX.Y.Z`)
4. GitHub Release with changelog notes
5. Updated demo app (blog_turbo) with new version

## Git Tags vs GitHub Releases

These are **separate entities**:
- Pushing a tag does NOT create a GitHub Release
- Must use `gh release create` for visible releases on the Releases page
- The "Latest" badge only appears on GitHub Releases, not raw tags
