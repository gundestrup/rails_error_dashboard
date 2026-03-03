---
description: Update the live demo app (blog_turbo) with the latest gem version
user-invocable: true
disable-model-invocation: true
---

# /demo-update — Update Demo App

Update the blog_turbo demo app to use the latest released gem version. Render auto-deploys on push.

## Usage

- `/demo-update` — update to latest released version
- `/demo-update 0.3.0` — update to a specific version

## Steps

1. **Read current gem version** from the demo app's Gemfile:
   ```bash
   grep rails_error_dashboard /Users/aj/code/test/blog_turbo/Gemfile
   ```

2. **Check latest released version** on RubyGems:
   ```bash
   gem search rails_error_dashboard --remote --exact
   ```

3. **Update the Gemfile** in `/Users/aj/code/test/blog_turbo/Gemfile`:
   Change the version constraint to `"~> X.Y.Z"`

4. **Update the lockfile**:
   ```bash
   cd /Users/aj/code/test/blog_turbo && bundle lock --update=rails_error_dashboard
   ```
   Note: Use `bundle lock` not `bundle install` — avoids compilation issues on Ruby 4.0.1 (sqlite3 2.8.1 doesn't compile on macOS).

5. **Check if seed file needs updates** — if the new version added features that need demo data, update `db/seeds.rb`

6. **Commit and push**:
   ```bash
   cd /Users/aj/code/test/blog_turbo
   git add Gemfile Gemfile.lock
   git commit -m "chore: update rails_error_dashboard to X.Y.Z"
   git push origin main
   ```

7. **Confirm deployment** — Render auto-deploys on push to main. The demo site will update within a few minutes.

## Demo App Details

- **Repo**: `AnjanJ/rails_error_dashboard_demo_app`
- **Location**: `/Users/aj/code/test/blog_turbo`
- **Live URL**: https://rails-error-dashboard.anjan.dev
- **Credentials**: gandalf / youshallnotpass
- **Platform**: Free Render instance
- **Uptime**: UptimeRobot pings every 5 minutes
- **Features**: ALL analytics enabled, source code + git blame, multi-app, separate DB
- **Seed data**: LOTR-themed (4 kingdoms, 480 errors, 296 comments, Fellowship members)
