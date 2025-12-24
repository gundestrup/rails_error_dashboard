source "https://rubygems.org"

# Specify your gem's dependencies in rails_error_dashboard.gemspec.
gemspec

# Allow testing against different Rails versions via RAILS_VERSION env var
# Use pessimistic version to get latest patch versions (e.g. ~> 7.0.1 gets latest 7.0.x)
rails_version = ENV['RAILS_VERSION'] || '~> 8.0.0'
rails_version = "~> #{rails_version}.1" if rails_version =~ /^\d+\.\d+$/
gem "rails", rails_version

gem "puma"

gem "pg"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
