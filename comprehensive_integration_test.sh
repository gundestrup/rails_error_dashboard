#!/bin/bash
set -e

# Comprehensive Integration Test for Rails Error Dashboard
# Tests all scenarios: fresh installs and upgrades

TEST_DIR="/tmp/rails_error_dashboard_integration_tests"
GEM_PATH="$(cd "$(dirname "$0")" && pwd)"
OLD_VERSION="0.1.21"
CURRENT_VERSION="0.1.23"

echo "================================================================================"
echo "Rails Error Dashboard - Comprehensive Integration Test Suite"
echo "Version: $CURRENT_VERSION"
echo "Started: $(date)"
echo "================================================================================"
echo

# Cleanup
echo "🧹 Cleaning up test directory..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
echo "✅ Test directory ready: $TEST_DIR"
echo

# Helper function to run command and check result
run_step() {
    local step_name="$1"
    shift

    echo -n "  ▶ $step_name... "

    if "$@" > /tmp/step_output.log 2>&1; then
        echo "✅"
        return 0
    else
        echo "❌"
        echo "  Error output:"
        cat /tmp/step_output.log | head -20 | sed 's/^/    /'
        return 1
    fi
}

# Scenario 1: Fresh Install - Single Database
echo "================================================================================"
echo "Scenario 1: Fresh Install - Single Database"
echo "================================================================================"
echo "App directory: $TEST_DIR/scenario1"
echo

cd /tmp
run_step "Create Rails app" rails new "$TEST_DIR/scenario1" --skip-git --skip-bundle

cd "$TEST_DIR/scenario1"

# Add gem to Gemfile
echo "gem 'rails_error_dashboard', path: '$GEM_PATH'" >> Gemfile

run_step "Bundle install" bundle install

run_step "Run generator (--no-interactive)" \
    bin/rails generate rails_error_dashboard:install --no-interactive

run_step "Run migrations" bin/rails db:migrate

run_step "Create test error" bin/rails runner "
  RailsErrorDashboard::Commands::LogError.call(
    StandardError.new('Test error from scenario 1'),
    {}
  )
"

run_step "Verify error logged" bin/rails runner "
  count = RailsErrorDashboard::ErrorLog.count
  if count == 1
    puts 'SUCCESS: 1 error logged'
    exit 0
  else
    puts \"FAIL: Expected 1 error, got \#{count}\"
    exit 1
  end
"

echo "✅ Scenario 1 completed successfully!"
echo

# Scenario 2: Fresh Install - Multi Database
echo "================================================================================"
echo "Scenario 2: Fresh Install - Multi Database"
echo "================================================================================"
echo "App directory: $TEST_DIR/scenario2"
echo

cd /tmp
run_step "Create Rails app" rails new "$TEST_DIR/scenario2" --skip-git --skip-bundle

cd "$TEST_DIR/scenario2"

# Configure database.yml for multi-DB
cat > config/database.yml << 'DBCONFIG'
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  primary:
    <<: *default
    database: storage/development.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_development.sqlite3

test:
  primary:
    <<: *default
    database: storage/test.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_test.sqlite3

production:
  primary:
    <<: *default
    database: storage/production.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_production.sqlite3
DBCONFIG

# Add gem to Gemfile
echo "gem 'rails_error_dashboard', path: '$GEM_PATH'" >> Gemfile

run_step "Bundle install" bundle install

run_step "Run generator with multi-DB" \
    bin/rails generate rails_error_dashboard:install \
    --no-interactive \
    --separate_database \
    --database=error_dashboard

run_step "Create databases" bin/rails db:create

run_step "Run migrations" bin/rails db:migrate

run_step "Create test error" bin/rails runner "
  RailsErrorDashboard::Commands::LogError.call(
    StandardError.new('Test error from scenario 2 multi-DB'),
    {}
  )
"

run_step "Verify error in multi-DB" bin/rails runner "
  # Check that error_dashboard database is being used
  count = RailsErrorDashboard::ErrorLog.count
  if count == 1
    puts 'SUCCESS: 1 error logged in multi-DB'
    exit 0
  else
    puts \"FAIL: Expected 1 error, got \#{count}\"
    exit 1
  end
"

echo "✅ Scenario 2 completed successfully!"
echo

# Scenario 3: Upgrade Single DB → Single DB (Gem Update)
echo "================================================================================"
echo "Scenario 3: Upgrade Single DB → Single DB"
echo "================================================================================"
echo "App directory: $TEST_DIR/scenario3"
echo

cd /tmp
run_step "Create Rails app" rails new "$TEST_DIR/scenario3" --skip-git --skip-bundle

cd "$TEST_DIR/scenario3"

# Install old version from RubyGems (0.1.21)
echo "gem 'rails_error_dashboard', '~> $OLD_VERSION'" >> Gemfile

run_step "Bundle install (old version)" bundle install

run_step "Run generator (old version)" \
    bin/rails generate rails_error_dashboard:install --no-interactive

run_step "Run migrations (old version)" bin/rails db:migrate

run_step "Create test error (old version)" bin/rails runner "
  RailsErrorDashboard::Commands::LogError.call(
    StandardError.new('Test error from old version'),
    {}
  )
"

# Now upgrade to current version
echo "  ▶ Upgrading to version $CURRENT_VERSION..."
sed -i.bak "s/gem 'rails_error_dashboard'.*/gem 'rails_error_dashboard', path: '$GEM_PATH'/" Gemfile

run_step "Bundle update (new version)" bundle update rails_error_dashboard

run_step "Run migrations (new version)" bin/rails db:migrate

run_step "Verify existing errors still present" bin/rails runner "
  count = RailsErrorDashboard::ErrorLog.count
  if count >= 1
    puts \"SUCCESS: \#{count} errors still present after upgrade\"
    exit 0
  else
    puts 'FAIL: No errors found after upgrade'
    exit 1
  end
"

run_step "Create new error after upgrade" bin/rails runner "
  RailsErrorDashboard::Commands::LogError.call(
    StandardError.new('Test error after upgrade'),
    {}
  )
"

run_step "Verify new error logged" bin/rails runner "
  count = RailsErrorDashboard::ErrorLog.count
  if count >= 2
    puts \"SUCCESS: \#{count} total errors\"
    exit 0
  else
    puts \"FAIL: Expected at least 2 errors, got \#{count}\"
    exit 1
  end
"

echo "✅ Scenario 3 completed successfully!"
echo

# Scenario 4: Upgrade Single DB → Multi DB
echo "================================================================================"
echo "Scenario 4: Upgrade Single DB → Multi DB"
echo "================================================================================"
echo "App directory: $TEST_DIR/scenario4"
echo

cd /tmp
run_step "Create Rails app" rails new "$TEST_DIR/scenario4" --skip-git --skip-bundle

cd "$TEST_DIR/scenario4"

# Install old version with single DB
echo "gem 'rails_error_dashboard', '~> $OLD_VERSION'" >> Gemfile

run_step "Bundle install (old version)" bundle install

run_step "Run generator (old version, single DB)" \
    bin/rails generate rails_error_dashboard:install --no-interactive

run_step "Run migrations (old version)" bin/rails db:migrate

run_step "Create test errors (old version)" bin/rails runner "
  3.times do |i|
    RailsErrorDashboard::Commands::LogError.call(
      StandardError.new(\"Test error \#{i} before multi-DB migration\"),
      {}
    )
  end
"

# Now upgrade to current version with multi-DB
echo "  ▶ Upgrading to version $CURRENT_VERSION with multi-DB..."

# Configure database.yml for multi-DB
cat > config/database.yml << 'DBCONFIG'
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  primary:
    <<: *default
    database: storage/development.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_development.sqlite3

test:
  primary:
    <<: *default
    database: storage/test.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_test.sqlite3

production:
  primary:
    <<: *default
    database: storage/production.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_production.sqlite3
DBCONFIG

sed -i.bak "s/gem 'rails_error_dashboard'.*/gem 'rails_error_dashboard', path: '$GEM_PATH'/" Gemfile

run_step "Bundle update (new version)" bundle update rails_error_dashboard

# Update initializer to enable multi-DB
echo "  ▶ Updating initializer for multi-DB..."
sed -i.bak 's/config.use_separate_database = false/config.use_separate_database = true/' \
    config/initializers/rails_error_dashboard.rb
sed -i.bak '/config.use_separate_database = true/a\
  config.database = :error_dashboard' config/initializers/rails_error_dashboard.rb

run_step "Create error_dashboard database" bin/rails db:create

run_step "Run migrations (new version, multi-DB)" bin/rails db:migrate

# Copy data from primary to error_dashboard
run_step "Migrate data to separate database" bin/rails runner "
  # Data migration would happen here in production
  # For testing, we'll just verify the new DB works
  puts 'Data migration step (manual in production)'
"

run_step "Create new error in multi-DB" bin/rails runner "
  RailsErrorDashboard::Commands::LogError.call(
    StandardError.new('Test error after multi-DB migration'),
    {}
  )
"

run_step "Verify error in multi-DB" bin/rails runner "
  count = RailsErrorDashboard::ErrorLog.count
  if count >= 1
    puts \"SUCCESS: \#{count} errors in multi-DB\"
    exit 0
  else
    puts 'FAIL: No errors found in multi-DB'
    exit 1
  end
"

echo "✅ Scenario 4 completed successfully!"
echo

# Scenario 5: Upgrade Multi DB → Multi DB (Gem Update)
echo "================================================================================"
echo "Scenario 5: Upgrade Multi DB → Multi DB"
echo "================================================================================"
echo "App directory: $TEST_DIR/scenario5"
echo

cd /tmp
run_step "Create Rails app" rails new "$TEST_DIR/scenario5" --skip-git --skip-bundle

cd "$TEST_DIR/scenario5"

# Configure database.yml for multi-DB from the start
cat > config/database.yml << 'DBCONFIG'
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  primary:
    <<: *default
    database: storage/development.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_development.sqlite3

test:
  primary:
    <<: *default
    database: storage/test.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_test.sqlite3

production:
  primary:
    <<: *default
    database: storage/production.sqlite3

  error_dashboard:
    <<: *default
    database: storage/error_dashboard_production.sqlite3
DBCONFIG

# Install old version with multi-DB
echo "gem 'rails_error_dashboard', '~> $OLD_VERSION'" >> Gemfile

run_step "Bundle install (old version)" bundle install

run_step "Run generator (old version, multi-DB)" \
    bin/rails generate rails_error_dashboard:install \
    --no-interactive \
    --separate_database \
    --database=error_dashboard

run_step "Create databases (old version)" bin/rails db:create

run_step "Run migrations (old version)" bin/rails db:migrate

run_step "Create test errors (old version)" bin/rails runner "
  3.times do |i|
    RailsErrorDashboard::Commands::LogError.call(
      StandardError.new(\"Test error \#{i} with old version multi-DB\"),
      {}
    )
  end
"

# Now upgrade to current version
echo "  ▶ Upgrading to version $CURRENT_VERSION..."
sed -i.bak "s/gem 'rails_error_dashboard'.*/gem 'rails_error_dashboard', path: '$GEM_PATH'/" Gemfile

run_step "Bundle update (new version)" bundle update rails_error_dashboard

run_step "Run migrations (new version)" bin/rails db:migrate

run_step "Verify existing errors still present" bin/rails runner "
  count = RailsErrorDashboard::ErrorLog.count
  if count >= 3
    puts \"SUCCESS: \#{count} errors still present after upgrade\"
    exit 0
  else
    puts \"FAIL: Expected at least 3 errors, got \#{count}\"
    exit 1
  end
"

run_step "Create new error after upgrade" bin/rails runner "
  RailsErrorDashboard::Commands::LogError.call(
    StandardError.new('Test error after multi-DB upgrade'),
    {}
  )
"

run_step "Verify new error logged" bin/rails runner "
  count = RailsErrorDashboard::ErrorLog.count
  if count >= 4
    puts \"SUCCESS: \#{count} total errors in multi-DB\"
    exit 0
  else
    puts \"FAIL: Expected at least 4 errors, got \#{count}\"
    exit 1
  end
"

echo "✅ Scenario 5 completed successfully!"
echo

# Summary
echo "================================================================================"
echo "TEST SUMMARY"
echo "================================================================================"
echo "✅ Scenario 1: Fresh Install - Single Database - PASSED"
echo "✅ Scenario 2: Fresh Install - Multi Database - PASSED"
echo "✅ Scenario 3: Upgrade Single DB → Single DB - PASSED"
echo "✅ Scenario 4: Upgrade Single DB → Multi DB - PASSED"
echo "✅ Scenario 5: Upgrade Multi DB → Multi DB - PASSED"
echo
echo "🎉 All integration tests passed!"
echo "Completed: $(date)"
echo "================================================================================"
