# frozen_string_literal: true

module RailsErrorDashboard
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs Rails Error Dashboard and generates the necessary files"

      class_option :interactive, type: :boolean, default: true, desc: "Interactive feature selection"
      class_option :slack, type: :boolean, default: false, desc: "Enable Slack notifications"
      class_option :email, type: :boolean, default: false, desc: "Enable email notifications"
      class_option :discord, type: :boolean, default: false, desc: "Enable Discord notifications"
      class_option :pagerduty, type: :boolean, default: false, desc: "Enable PagerDuty notifications"
      class_option :webhooks, type: :boolean, default: false, desc: "Enable webhook notifications"
      class_option :async_logging, type: :boolean, default: false, desc: "Enable async error logging"
      class_option :separate_database, type: :boolean, default: false, desc: "Use separate database for errors"

      def welcome_message
        say "\n"
        say "=" * 70
        say "  📊 Rails Error Dashboard Installation", :cyan
        say "=" * 70
        say "\n"
        say "Core features will be enabled automatically:", :green
        say "  ✓ Error capture (controllers, jobs, middleware)"
        say "  ✓ Dashboard UI at /error_dashboard"
        say "  ✓ Real-time updates"
        say "  ✓ Analytics & spike detection"
        say "  ✓ 90-day error retention"
        say "\n"
      end

      def select_optional_features
        return unless options[:interactive] && behavior == :invoke

        say "Let's configure optional features...\n", :cyan
        say "(You can always enable/disable these later in the initializer)\n\n", :yellow

        @selected_features = {}

        # Feature definitions with descriptions
        features = [
          {
            key: :slack,
            name: "Slack Notifications",
            description: "Send error alerts to Slack channels (requires webhook URL)"
          },
          {
            key: :email,
            name: "Email Notifications",
            description: "Send error alerts via email (requires ActionMailer setup)"
          },
          {
            key: :discord,
            name: "Discord Notifications",
            description: "Send error alerts to Discord channels (requires webhook URL)"
          },
          {
            key: :pagerduty,
            name: "PagerDuty Integration",
            description: "Send critical errors to PagerDuty (requires integration key)"
          },
          {
            key: :webhooks,
            name: "Generic Webhooks",
            description: "Send error data to custom webhook endpoints"
          },
          {
            key: :async_logging,
            name: "Async Error Logging",
            description: "Process errors in background jobs (requires Sidekiq/Solid Queue)"
          },
          {
            key: :separate_database,
            name: "Separate Error Database",
            description: "Store errors in dedicated database (requires DB setup)"
          }
        ]

        features.each_with_index do |feature, index|
          say "\n[#{index + 1}/#{features.length}] #{feature[:name]}", :cyan
          say "    #{feature[:description]}", :light_black

          # Check if feature was passed via command line option
          if options[feature[:key]]
            @selected_features[feature[:key]] = true
            say "    ✓ Enabled (via --#{feature[:key]} flag)", :green
          else
            response = ask("    Enable? (y/N):", :yellow, limited_to: ["y", "Y", "n", "N", ""])
            @selected_features[feature[:key]] = response.downcase == "y"

            if @selected_features[feature[:key]]
              say "    ✓ Enabled", :green
            else
              say "    ✗ Disabled", :light_black
            end
          end
        end

        say "\n"
      end

      def create_initializer_file
        @enable_slack = @selected_features&.dig(:slack) || options[:slack]
        @enable_email = @selected_features&.dig(:email) || options[:email]
        @enable_discord = @selected_features&.dig(:discord) || options[:discord]
        @enable_pagerduty = @selected_features&.dig(:pagerduty) || options[:pagerduty]
        @enable_webhooks = @selected_features&.dig(:webhooks) || options[:webhooks]
        @enable_async_logging = @selected_features&.dig(:async_logging) || options[:async_logging]
        @enable_separate_database = @selected_features&.dig(:separate_database) || options[:separate_database]

        template "initializer.rb", "config/initializers/rails_error_dashboard.rb"
      end

      def copy_migrations
        rake "rails_error_dashboard:install:migrations"
      end

      def add_route
        route "mount RailsErrorDashboard::Engine => '/error_dashboard'"
      end

      def show_feature_summary
        return unless behavior == :invoke

        say "\n"
        say "=" * 70
        say "  ✓ Installation Complete!", :green
        say "=" * 70
        say "\n"

        say "Enabled Features:", :cyan
        say "  ✓ Error Capture", :green
        say "  ✓ Dashboard UI", :green
        say "  ✓ Real-time Updates", :green
        say "  ✓ Analytics", :green

        if @enable_slack
          say "  ✓ Slack Notifications", :green
          say "    → Set SLACK_WEBHOOK_URL in .env", :yellow
        end

        if @enable_email
          say "  ✓ Email Notifications", :green
          say "    → Set ERROR_NOTIFICATION_EMAILS in .env", :yellow
        end

        if @enable_discord
          say "  ✓ Discord Notifications", :green
          say "    → Set DISCORD_WEBHOOK_URL in .env", :yellow
        end

        if @enable_pagerduty
          say "  ✓ PagerDuty Integration", :green
          say "    → Set PAGERDUTY_INTEGRATION_KEY in .env", :yellow
        end

        if @enable_webhooks
          say "  ✓ Webhook Notifications", :green
          say "    → Set WEBHOOK_URLS in .env", :yellow
        end

        if @enable_async_logging
          say "  ✓ Async Error Logging", :green
          say "    → Ensure Sidekiq/Solid Queue is running", :yellow
        end

        if @enable_separate_database
          say "  ✓ Separate Error Database", :green
          say "    → Configure database.yml (see docs/guides/DATABASE_OPTIONS.md)", :yellow
        end

        say "\n"
        say "Next Steps:", :cyan
        say "  1. Run: rails db:migrate"
        say "  2. Update credentials in config/initializers/rails_error_dashboard.rb"
        if @enable_slack || @enable_email || @enable_discord || @enable_pagerduty || @enable_webhooks
          say "  3. Configure notification settings (see .env variables above)"
        end
        say "  #{@enable_slack || @enable_email ? 4 : 3}. Restart your Rails server"
        say "  #{@enable_slack || @enable_email ? 5 : 4}. Visit http://localhost:3000/error_dashboard"
        say "\n"
        say "📖 Documentation: docs/QUICKSTART.md", :light_black
        say "⚙️  To change settings later: config/initializers/rails_error_dashboard.rb", :light_black
        say "\n"
      end

      def show_readme
        # Skip the old README display since we have the new summary
      end
    end
  end
end
