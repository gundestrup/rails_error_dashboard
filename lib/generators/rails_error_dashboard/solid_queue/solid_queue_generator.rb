# frozen_string_literal: true

module RailsErrorDashboard
  module Generators
    # Generator for Solid Queue configuration
    # Usage: rails generate rails_error_dashboard:solid_queue
    class SolidQueueGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates Solid Queue configuration for RailsErrorDashboard"

      def create_queue_config
        template "queue.yml", "config/queue.yml"
      end

      def show_instructions
        say "\n" + "=" * 80, :green
        say "Solid Queue configuration created!", :green
        say "=" * 80, :green
        say "\nNext steps:", :yellow
        say "  1. Install Solid Queue gem (if not already):", :cyan
        say "     bundle add solid_queue", :white
        say "\n  2. Run Solid Queue migrations:", :cyan
        say "     bin/rails solid_queue:install", :white
        say "\n  3. Set ActiveJob adapter in config/application.rb:", :cyan
        say "     config.active_job.queue_adapter = :solid_queue", :white
        say "\n  4. Start Solid Queue worker:", :cyan
        say "     bin/jobs", :white
        say "\n  5. Enable async logging in config/initializers/rails_error_dashboard.rb:", :cyan
        say "     config.async_logging = true", :white
        say "     config.async_adapter = :solid_queue", :white
        say "\n" + "=" * 80, :green
      end
    end
  end
end
