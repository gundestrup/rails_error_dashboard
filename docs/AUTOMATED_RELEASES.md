# Automated Release Setup Guide

This guide explains how automated releases work for `rails_error_dashboard` and how to set them up.

## Overview

We use **Release Please** + **Trusted Publishing** for fully automated gem releases:

- **Release Please** (Google) - Automates versioning and CHANGELOG generation
- **Trusted Publishing** (RubyGems) - Secure publishing without API tokens
- **Conventional Commits** - Determines version bumps automatically

## How It Works

### 1. Development Workflow

Developers use **conventional commit messages**:

```bash
# Patch release (0.1.0 → 0.1.1)
git commit -m "fix: resolve dark mode persistence issue"

# Minor release (0.1.0 → 0.2.0)
git commit -m "feat: add Discord notification support"

# Major release (0.1.0 → 1.0.0)
git commit -m "feat!: redesign configuration API

BREAKING CHANGE: Configuration options have been renamed"
```

### 2. Automated Release PR

When commits are pushed to `main`:

1. **Release Please** analyzes commits since last release
2. Creates/updates a **Release PR** with:
   - Version bump in `version.rb`
   - Updated `CHANGELOG.md` with grouped changes
   - Updated `.release-please-manifest.json`

Example Release PR:
```
Title: "chore(main): release 0.2.0"

Changes:
- lib/rails_error_dashboard/version.rb: 0.1.1 → 0.2.0
- CHANGELOG.md: New section for 0.2.0
- .release-please-manifest.json: Updated version
```

### 3. Publishing

When you **merge the Release PR**:

1. GitHub Actions detects the merge
2. Runs tests and RuboCop
3. Publishes gem to RubyGems.org via Trusted Publishing
4. Creates GitHub release with notes

**No manual steps required!**

## Initial Setup

### Step 1: Enable Trusted Publishing on RubyGems.org

1. **Login to RubyGems.org** with your account
2. **Navigate to your gem**: https://rubygems.org/gems/rails_error_dashboard
3. **Go to "Trusted Publishers"** in the gem settings
4. **Click "Add"** to create a new publisher

5. **Fill in the form**:
   ```
   Repository owner: AnjanJ
   Repository name: rails_error_dashboard
   Workflow filename: release.yml
   Environment name: (leave blank or use "release")
   ```

6. **Save** the trusted publisher

**That's it!** No API keys to manage or rotate.

### Step 2: Grant GitHub Actions Permissions

In your GitHub repository:

1. Go to **Settings → Actions → General**
2. Under **Workflow permissions**, select:
   - ✅ "Read and write permissions"
   - ✅ "Allow GitHub Actions to create and approve pull requests"
3. **Save**

### Step 3: Verify Configuration Files

These files are already in the repository:

- `.release-please-manifest.json` - Tracks current version
- `.release-please-config.json` - Release behavior configuration
- `.github/workflows/release.yml` - Automation workflow

## Conventional Commit Format

### Commit Types

| Prefix | Version Bump | Description | Example |
|--------|-------------|-------------|---------|
| `fix:` | Patch (0.1.0 → 0.1.1) | Bug fixes | `fix: correct error grouping logic` |
| `feat:` | Minor (0.1.0 → 0.2.0) | New features | `feat: add Jira integration` |
| `feat!:` or `BREAKING CHANGE:` | Major (0.1.0 → 1.0.0) | Breaking changes | `feat!: rename config options` |
| `docs:` | None | Documentation only | `docs: update README examples` |
| `test:` | None | Test changes | `test: add specs for new feature` |
| `chore:` | None | Maintenance | `chore: update dependencies` |
| `refactor:` | None | Code refactoring | `refactor: simplify query logic` |
| `perf:` | Patch | Performance improvements | `perf: optimize error matching` |

### CHANGELOG Sections

Commits are automatically grouped in CHANGELOG:

- ✨ **Features** - `feat:` commits
- 🐛 **Bug Fixes** - `fix:` commits
- ⚡ **Performance** - `perf:` commits
- 📚 **Documentation** - `docs:` commits
- 🧪 **Testing** - `test:` commits
- ♻️ **Refactoring** - `refactor:` commits
- 🧹 **Maintenance** - `chore:` commits

### Commit Examples

**Bug fix:**
```bash
git commit -m "fix: prevent duplicate error notifications

Resolves #123"
```

**New feature:**
```bash
git commit -m "feat: add support for custom error grouping

Users can now define custom grouping strategies via configuration.
This enables more flexible error deduplication."
```

**Breaking change:**
```bash
git commit -m "feat!: redesign notification configuration

BREAKING CHANGE: The notification configuration format has changed.
Old: config.slack_webhook = 'url'
New: config.notifications.slack.webhook = 'url'

Migration guide: docs/MIGRATION_v2.md"
```

**Multiple commits:**
```bash
git commit -m "fix: resolve dark mode flash"
git commit -m "fix: correct form HTTP method"
git commit -m "test: add specs for error filtering"
# All three will be in the same release!
```

## Release Workflow

### Normal Release Process

1. **Develop features** on feature branches
2. **Create PR** to `main` with conventional commits
3. **Merge PR** - Release Please creates/updates Release PR automatically
4. **Review Release PR** - Check version bump and CHANGELOG
5. **Merge Release PR** - Gem publishes automatically

### Emergency Release

If you need to release immediately:

**Option 1: Merge existing Release PR**
```bash
# Check if Release PR exists
gh pr list --label "autorelease: pending"

# Merge it
gh pr merge <PR_NUMBER> --merge
```

**Option 2: Manual release (fallback)**
```bash
# Only use if automation fails
gem build rails_error_dashboard.gemspec
gem push rails_error_dashboard-0.1.2.gem
```

### Skipping CI for Docs

Documentation-only changes don't need to trigger releases:

```bash
git commit -m "docs: update README [skip ci]"
```

## Monitoring Releases

### Check Release PR Status

```bash
# List all Release PRs
gh pr list --label "autorelease: pending"

# View Release PR details
gh pr view <PR_NUMBER>
```

### Check Release Workflow

```bash
# View recent workflow runs
gh run list --workflow=release.yml

# View specific run details
gh run view <RUN_ID>
```

### Verify RubyGems Publication

After Release PR merges:

1. Check GitHub Actions: https://github.com/AnjanJ/rails_error_dashboard/actions
2. Verify on RubyGems: https://rubygems.org/gems/rails_error_dashboard
3. Test installation: `gem install rails_error_dashboard`

## Troubleshooting

### Release PR Not Created

**Problem:** Commits pushed but no Release PR appears

**Solutions:**
1. Ensure commits use conventional format (`feat:`, `fix:`, etc.)
2. Check GitHub Actions workflow ran: `gh run list`
3. Verify permissions in Settings → Actions → General
4. Check `.release-please-config.json` is valid JSON

### Gem Publishing Failed

**Problem:** Release PR merged but gem didn't publish

**Solutions:**
1. Check GitHub Actions logs: `gh run view <RUN_ID>`
2. Verify Trusted Publisher is configured on RubyGems.org
3. Ensure workflow has `id-token: write` permission
4. Check tests/RuboCop passed before publishing step

### Wrong Version Bump

**Problem:** Release Please bumped wrong version number

**Solutions:**
1. Use correct commit prefix (`feat:` for minor, `fix:` for patch)
2. For breaking changes, use `feat!:` or add `BREAKING CHANGE:` footer
3. Edit Release PR manually if needed (edit version.rb and CHANGELOG.md)

### Manual Version Override

If you need to force a specific version:

1. **Edit** `.release-please-manifest.json`:
   ```json
   {
     ".": "0.2.0"  # Force next release to be 0.2.0
   }
   ```

2. **Commit and push**:
   ```bash
   git add .release-please-manifest.json
   git commit -m "chore: force version to 0.2.0"
   git push
   ```

3. **Release Please** will use this version for next release

## Security Considerations

### Trusted Publishing vs API Tokens

**Trusted Publishing (Recommended):**
- ✅ No secrets to manage
- ✅ Short-lived tokens (expire after use)
- ✅ Tied to specific repository and workflow
- ✅ Can't be leaked or stolen
- ✅ Zero configuration drift

**API Tokens (Legacy):**
- ❌ Long-lived credentials
- ❌ Must be stored as GitHub secret
- ❌ Requires manual rotation
- ❌ Risk of leakage
- ❌ Not recommended for new projects

### Access Control

Only repository owners can:
- Configure Trusted Publishers on RubyGems.org
- Modify GitHub Actions workflows
- Merge Release PRs (which trigger publishing)

This ensures only authorized releases happen.

## Best Practices

### 1. Review Release PRs Carefully

Always review the Release PR before merging:
- Check version bump is correct
- Review CHANGELOG entries
- Verify breaking changes are documented
- Ensure all tests pass

### 2. Use Descriptive Commit Messages

Good:
```bash
git commit -m "fix: prevent duplicate notifications when error occurs multiple times

Added deduplication check in NotificationJob to avoid spamming
users with the same error repeatedly."
```

Bad:
```bash
git commit -m "fix stuff"
```

### 3. Batch Related Changes

Group related commits in one PR:
```bash
# One PR with multiple fixes
git commit -m "fix: dark mode persistence"
git commit -m "fix: resolve button action"
git commit -m "test: add specs for UI fixes"
# All included in same release
```

### 4. Document Breaking Changes

For breaking changes, always include migration guide:
```bash
git commit -m "feat!: redesign configuration API

BREAKING CHANGE: Configuration format has changed.

Migration guide:
- Old: config.slack_webhook = 'url'
- New: config.notifications.slack.webhook = 'url'

See docs/MIGRATION_v2.md for full details."
```

### 5. Test Before Merging Release PR

Before merging Release PR:
1. Check GitHub Actions passed
2. Review test coverage report
3. Verify no RuboCop violations
4. Confirm CHANGELOG is accurate

## FAQ

### Q: Can I still do manual releases?

**A:** Yes! The automation is optional. You can always:
```bash
gem build rails_error_dashboard.gemspec
gem push rails_error_dashboard-X.Y.Z.gem
```

But automated releases are more reliable and consistent.

### Q: What if I make a mistake in a release?

**A:** You can yank the gem and release a new version:
```bash
gem yank rails_error_dashboard -v 0.1.2
# Fix the issue
# Push new commits to trigger new release
```

### Q: Can I skip a release?

**A:** Yes! Just don't merge the Release PR. It will accumulate commits until you're ready.

### Q: How do I do a pre-release (alpha/beta)?

**A:** Manually edit the version in Release PR:
```ruby
# In version.rb
VERSION = "0.2.0.beta1"
```

Or use conventional commit for pre-release:
```bash
git commit -m "feat: add experimental feature (alpha)"
```

### Q: What if automation breaks?

**A:** Fallback to manual process:
1. Update `version.rb` manually
2. Update `CHANGELOG.md` manually
3. Build and push gem: `gem build && gem push`
4. Create GitHub release manually

## Resources

- [Release Please Documentation](https://github.com/googleapis/release-please)
- [Trusted Publishing Guide](https://guides.rubygems.org/trusted-publishing/)
- [Conventional Commits Spec](https://www.conventionalcommits.org/)
- [RubyGems Publishing Guide](https://guides.rubygems.org/publishing/)

## Support

If you encounter issues with automated releases:

1. Check GitHub Actions logs
2. Review this guide's troubleshooting section
3. Open an issue: https://github.com/AnjanJ/rails_error_dashboard/issues

---

**Note:** After initial setup, releases are fully automated. Just use conventional commits and merge the Release PRs!
