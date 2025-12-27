# frozen_string_literal: true

require "rails_helper"
require "generators/rails_error_dashboard/uninstall/uninstall_generator"

RSpec.describe RailsErrorDashboard::Generators::UninstallGenerator, type: :generator do
  describe "uninstall generator" do
    it "exists and is loadable" do
      expect(described_class).to be_a(Class)
      expect(described_class.ancestors).to include(Rails::Generators::Base)
    end

    it "has correct class options" do
      expect(described_class.class_options.keys).to include(:keep_data)
      expect(described_class.class_options.keys).to include(:skip_confirmation)
      expect(described_class.class_options.keys).to include(:manual_only)
    end

    it "has all required methods" do
      generator = described_class.new
      expect(generator).to respond_to(:welcome_message)
      expect(generator).to respond_to(:detect_installed_components)
      expect(generator).to respond_to(:show_manual_instructions)
      expect(generator).to respond_to(:remove_initializer)
      expect(generator).to respond_to(:remove_route)
      expect(generator).to respond_to(:remove_migrations)
      expect(generator).to respond_to(:drop_database_tables)
    end
  end

  describe "component detection helpers" do
    let(:generator) { described_class.new }

    describe "#route_mounted?" do
      it "returns false when routes.rb doesn't exist" do
        allow(File).to receive(:exist?).with("config/routes.rb").and_return(false)
        expect(generator.send(:route_mounted?)).to be false
      end

      it "returns true when RailsErrorDashboard::Engine is mounted" do
        allow(File).to receive(:exist?).with("config/routes.rb").and_return(true)
        allow(File).to receive(:read).with("config/routes.rb").and_return(
          "mount RailsErrorDashboard::Engine => '/error_dashboard'"
        )
        expect(generator.send(:route_mounted?)).to be true
      end
    end

    describe "#migrations_exist?" do
      it "returns true when migration files exist" do
        allow(Dir).to receive(:glob).with("db/migrate/*rails_error_dashboard*.rb").and_return(
          [ "db/migrate/20251224_create_rails_error_dashboard_error_logs.rb" ]
        )
        expect(generator.send(:migrations_exist?)).to be true
      end

      it "returns false when no migration files exist" do
        allow(Dir).to receive(:glob).with("db/migrate/*rails_error_dashboard*.rb").and_return([])
        expect(generator.send(:migrations_exist?)).to be false
      end
    end

    describe "#gemfile_includes_gem?" do
      it "returns true when gem is in Gemfile" do
        allow(File).to receive(:exist?).with("Gemfile").and_return(true)
        allow(File).to receive(:read).with("Gemfile").and_return("gem 'rails_error_dashboard'")
        expect(generator.send(:gemfile_includes_gem?)).to be true
      end

      it "returns false when gem is not in Gemfile" do
        allow(File).to receive(:exist?).with("Gemfile").and_return(true)
        allow(File).to receive(:read).with("Gemfile").and_return("gem 'rails'")
        expect(generator.send(:gemfile_includes_gem?)).to be false
      end
    end
  end

  describe "table names" do
    let(:generator) { described_class.new }

    it "returns all expected table names" do
      table_names = generator.send(:table_names)
      expect(table_names).to include("rails_error_dashboard_error_logs")
      expect(table_names).to include("rails_error_dashboard_error_occurrences")
      expect(table_names).to include("rails_error_dashboard_cascade_patterns")
      expect(table_names).to include("rails_error_dashboard_error_baselines")
      expect(table_names).to include("rails_error_dashboard_error_comments")
    end
  end
end
