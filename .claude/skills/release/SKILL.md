---
description: Full gem release workflow — version bump, changelog, publish, tag, GitHub release, demo update
user-invocable: true
disable-model-invocation: true
---

# /release — Gem Release Workflow

Release a new version of rails_error_dashboard. This is a two-phase process with a mandatory approval gate.

## Arguments

`/release <version>` — e.g., `/release 0.4.0`

If no version is provided, ask the user what version to release.

## Phase 1: Prepare (Safe / Reversible)

1. **Read current version** from `lib/rails_error_dashboard/version.rb`
2. **Bump version** in `lib/rails_error_dashboard/version.rb`
3. **Update CHANGELOG.md** — add new version entry at the top with today's date and a summary of changes since the last release. Read recent git log to determine what changed:
   ```bash
   git log --oneline $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD
   ```
4. **Update README.md** — update any version references if needed
5. **Run the full test suite**:
   ```bash
   bundle exec rspec
   ```
6. **Commit**:
   ```
   chore: bump version to X.Y.Z
   ```
7. **Push to main**:
   ```bash
   git push origin main
   ```

## MANDATORY APPROVAL GATE

**STOP HERE.** Tell the user:

> Phase 1 complete. Version bumped to X.Y.Z, changelog updated, tests passing, pushed to main.
>
> Phase 2 will publish to RubyGems and create a GitHub release. This is irreversible.
>
> Ready to publish vX.Y.Z?

**Do NOT proceed to Phase 2 without explicit "yes" from the user.**

## Phase 2: Publish (Irreversible)

8. **Build the gem**:
   ```bash
   gem build rails_error_dashboard.gemspec
   ```
9. **Push to RubyGems**:
   ```bash
   gem push rails_error_dashboard-X.Y.Z.gem
   ```
10. **Create git tag and push**:
    ```bash
    git tag vX.Y.Z
    git push origin vX.Y.Z
    ```
11. **Create GitHub Release**:
    ```bash
    gh release create vX.Y.Z --title "vX.Y.Z" --notes "<changelog excerpt>"
    ```
12. **Clean up** the `.gem` file:
    ```bash
    rm rails_error_dashboard-X.Y.Z.gem
    ```

## Phase 3: Demo Update

13. **Update the demo app** (blog_turbo):
    ```bash
    cd /Users/aj/code/test/blog_turbo
    ```
    - Update `Gemfile`: `gem "rails_error_dashboard", "~> X.Y.Z"`
    - Run `bundle lock --update=rails_error_dashboard`
    - Update seed file if new features need demo data
    - Commit and push — Render auto-deploys

## Important Notes

- RubyGems auth uses `~/.gem/credentials`
- Git tags and GitHub Releases are separate — pushing a tag does NOT create a release
- Demo app repo: `AnjanJ/rails_error_dashboard_demo_app`
- Demo site: https://rails-error-dashboard.anjan.dev
