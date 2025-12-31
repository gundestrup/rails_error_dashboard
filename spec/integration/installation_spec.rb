# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'Installation and Upgrade', type: :integration, skip: "Use bin/test-installation instead" do
  let(:test_dir) { Dir.mktmpdir('rails_error_dashboard_install_test') }
  let(:gem_root) { File.expand_path('../..', __dir__) }
  let(:previous_version) { '0.1.10' }
  let(:current_version) { RailsErrorDashboard::VERSION }

  before(:all) do
    # Ensure we're running on the correct Ruby and Rails versions
    ruby_version = RUBY_VERSION
    rails_version = Rails.version rescue nil

    puts "\n=========================================="
    puts "Installation Test Environment"
    puts "=========================================="
    puts "Ruby Version: #{ruby_version}"
    puts "Rails Version: #{rails_version}" if rails_version
    puts "Gem Version: #{RailsErrorDashboard::VERSION}"
    puts "=========================================="
  end

  after(:each) do
    FileUtils.rm_rf(test_dir) if File.exist?(test_dir)
  end

  describe 'Fresh Installation' do
    it 'installs successfully in a new Rails 8.1.1 app with Ruby 3.4.8' do
      skip "Rails not available" unless defined?(Rails)

      within_test_app(test_dir, 'fresh_install_test') do |app_dir|
        # Add gem to Gemfile
        add_gem_to_gemfile(app_dir, :local)

        # Run bundle install
        expect(run_command('bundle install')).to be_success

        # Run generator
        expect(run_command('rails generate rails_error_dashboard:install')).to be_success

        # Verify files were created
        expect(File.exist?("#{app_dir}/config/initializers/rails_error_dashboard.rb")).to be true
        expect(File.exist?("#{app_dir}/config/routes.rb")).to be true

        # Verify routes were added
        routes_content = File.read("#{app_dir}/config/routes.rb")
        expect(routes_content).to include('mount RailsErrorDashboard::Engine')

        # Run migrations
        expect(run_command('rails db:create db:migrate')).to be_success

        # Verify tables exist
        tables = run_command('rails runner "puts ActiveRecord::Base.connection.tables.join(\',\')"').output
        expect(tables).to include('error_logs')

        # Verify gem is loadable
        expect(run_command('rails runner "puts RailsErrorDashboard::VERSION"')).to be_success

        # Test error logging
        result = run_command('rails runner "begin; raise \'Test error\'; rescue => e; RailsErrorDashboard::Commands::LogError.call(e); end"')
        expect(result).to be_success

        # Verify error was logged
        error_count = run_command('rails runner "puts RailsErrorDashboard::ErrorLog.count"').output.strip.to_i
        expect(error_count).to eq(1)

        puts "✅ Fresh installation test passed!"
      end
    end

    it 'creates all necessary database tables and indexes' do
      skip "Rails not available" unless defined?(Rails)

      within_test_app(test_dir, 'tables_test') do |app_dir|
        add_gem_to_gemfile(app_dir, :local)
        run_command('bundle install')
        run_command('rails generate rails_error_dashboard:install')
        run_command('rails db:create db:migrate')

        # Check all required tables exist
        tables = run_command('rails runner "puts ActiveRecord::Base.connection.tables.join(\',\')"').output
        expect(tables).to include('error_logs')
        expect(tables).to include('error_baselines')
        expect(tables).to include('error_cascade_patterns')
        expect(tables).to include('error_comments')

        # Verify indexes exist
        indexes_cmd = 'rails runner "puts ActiveRecord::Base.connection.indexes(:error_logs).map(&:name).join(\',\')"'
        indexes = run_command(indexes_cmd).output

        # Check for performance indexes
        expect(indexes).to include('index_error_logs_on_occurred_at')
        expect(indexes).to include('index_error_logs_on_error_type')

        puts "✅ Database schema test passed!"
      end
    end
  end

  describe 'Upgrade from Previous Version' do
    it 'upgrades successfully from v0.1.10 to current version' do
      skip "Rails not available" unless defined?(Rails)
      skip "Already at target version" if previous_version == current_version

      within_test_app(test_dir, 'upgrade_test') do |app_dir|
        # Install previous version
        add_gem_to_gemfile(app_dir, :rubygems, previous_version)
        expect(run_command('bundle install')).to be_success
        expect(run_command('rails generate rails_error_dashboard:install')).to be_success
        expect(run_command('rails db:create db:migrate')).to be_success

        # Create some test data with old version
        create_test_data_script = <<~RUBY
          3.times do |i|
            RailsErrorDashboard::ErrorLog.create!(
              error_type: 'StandardError',
              message: "Test error \#{i}",
              occurred_at: Time.current,
              severity: :high,
              platform: 'API'
            )
          end
          puts "Created \#{RailsErrorDashboard::ErrorLog.count} errors"
        RUBY

        File.write("#{app_dir}/tmp/create_test_data.rb", create_test_data_script)
        result = run_command('rails runner tmp/create_test_data.rb')
        expect(result.output).to include("Created 3 errors")

        # Upgrade to current version
        add_gem_to_gemfile(app_dir, :local)
        expect(run_command('bundle update rails_error_dashboard')).to be_success

        # Run new migrations
        expect(run_command('rails rails_error_dashboard:install:migrations')).to be_success
        expect(run_command('rails db:migrate')).to be_success

        # Verify old data is preserved
        error_count = run_command('rails runner "puts RailsErrorDashboard::ErrorLog.count"').output.strip.to_i
        expect(error_count).to eq(3)

        # Verify new features work
        result = run_command('rails runner "puts RailsErrorDashboard::VERSION"')
        expect(result.output.strip).to eq(current_version)

        # Test new error logging still works
        run_command('rails runner "begin; raise \'New error\'; rescue => e; RailsErrorDashboard::Commands::LogError.call(e); end"')
        new_count = run_command('rails runner "puts RailsErrorDashboard::ErrorLog.count"').output.strip.to_i
        expect(new_count).to eq(4)

        puts "✅ Upgrade test passed! (#{previous_version} → #{current_version})"
      end
    end

    it 'migrates existing configuration correctly' do
      skip "Rails not available" unless defined?(Rails)
      skip "Already at target version" if previous_version == current_version

      within_test_app(test_dir, 'config_migration_test') do |app_dir|
        # Install previous version
        add_gem_to_gemfile(app_dir, :rubygems, previous_version)
        run_command('bundle install')
        run_command('rails generate rails_error_dashboard:install')

        # Modify initializer with custom settings
        initializer_path = "#{app_dir}/config/initializers/rails_error_dashboard.rb"
        original_config = File.read(initializer_path)

        custom_config = original_config.sub(
          'config.retention_days = 90',
          'config.retention_days = 30'
        )
        File.write(initializer_path, custom_config)

        run_command('rails db:create db:migrate')

        # Upgrade
        add_gem_to_gemfile(app_dir, :local)
        run_command('bundle update rails_error_dashboard')
        run_command('rails rails_error_dashboard:install:migrations')
        run_command('rails db:migrate')

        # Verify custom configuration is preserved
        config_content = File.read(initializer_path)
        expect(config_content).to include('config.retention_days = 30')

        # Verify config still loads
        result = run_command('rails runner "puts RailsErrorDashboard.configuration.retention_days"')
        expect(result.output.strip).to eq('30')

        puts "✅ Configuration migration test passed!"
      end
    end
  end

  describe 'Post-Installation Functionality' do
    it 'successfully loads all routes and pages' do
      skip "Rails not available" unless defined?(Rails)

      within_test_app(test_dir, 'routes_test') do |app_dir|
        add_gem_to_gemfile(app_dir, :local)
        run_command('bundle install')
        run_command('rails generate rails_error_dashboard:install')
        run_command('rails db:create db:migrate')

        # Start Rails in test mode
        routes_output = run_command('rails routes | grep error_dashboard').output

        # Verify key routes exist
        expect(routes_output).to include('error_dashboard')
        expect(routes_output).to include('errors')
        expect(routes_output).to include('analytics')

        puts "✅ Routes test passed!"
      end
    end

    it 'handles concurrent installations gracefully' do
      skip "Rails not available" unless defined?(Rails)

      within_test_app(test_dir, 'concurrent_test') do |app_dir|
        add_gem_to_gemfile(app_dir, :local)
        run_command('bundle install')

        # Run generator twice (simulating concurrent or repeated installation)
        run_command('rails generate rails_error_dashboard:install')
        result = run_command('rails generate rails_error_dashboard:install')

        # Should not error, just skip existing files
        expect(result).to be_success

        run_command('rails db:create db:migrate')

        # Run migrations twice
        result = run_command('rails db:migrate')
        expect(result).to be_success

        puts "✅ Concurrent installation test passed!"
      end
    end
  end

  private

  def within_test_app(base_dir, app_name)
    app_dir = File.join(base_dir, app_name)
    FileUtils.mkdir_p(base_dir)

    Dir.chdir(base_dir) do
      # Create new Rails app
      system("rails new #{app_name} --skip-git --skip-javascript --skip-hotwire --database=sqlite3 --quiet", out: File::NULL, err: File::NULL)

      Dir.chdir(app_dir) do
        yield(app_dir)
      end
    end
  end

  def add_gem_to_gemfile(app_dir, source, version = nil)
    gemfile = File.join(app_dir, 'Gemfile')
    content = File.read(gemfile)

    gem_line = case source
    when :local
                  "gem 'rails_error_dashboard', path: '#{gem_root}'"
    when :rubygems
                  version ? "gem 'rails_error_dashboard', '#{version}'" : "gem 'rails_error_dashboard'"
    end

    # Remove any existing gem line
    content.gsub!(/^gem ['"]rails_error_dashboard['"].*$/, '')

    # Add new gem line
    content += "\n#{gem_line}\n"

    File.write(gemfile, content)
  end

  def run_command(command)
    output = `#{command} 2>&1`
    CommandResult.new($?.success?, output)
  end

  class CommandResult
    attr_reader :success, :output

    def initialize(success, output)
      @success = success
      @output = output
    end

    def be_success
      raise RSpec::Expectations::ExpectationNotMetError, "Command failed:\n#{output}" unless success
      true
    end
  end
end
