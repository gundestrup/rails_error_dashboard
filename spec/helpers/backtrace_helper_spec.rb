# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::BacktraceHelper, type: :helper do
  let(:test_file) { File.join(Rails.root, "app/models/test_model.rb") }
  let(:test_content) do
    <<~RUBY
      class TestModel < ApplicationRecord
        validates :name, presence: true

        def process
          # Line 5
          raise "Test error"
        end
      end
    RUBY
  end

  before do
    FileUtils.mkdir_p(File.dirname(test_file))
    File.write(test_file, test_content)
  end

  after do
    FileUtils.rm_f(test_file)
  end

  describe "#read_source_code" do
    let(:frame) do
      {
        file_path: test_file,
        line_number: 6,
        short_path: "app/models/test_model.rb",
        category: :app
      }
    end

    context "when source code integration is enabled" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
        RailsErrorDashboard.configuration.source_code_context_lines = 2
      end

      it "reads source code for a frame" do
        result = helper.read_source_code(frame)

        expect(result).to be_a(Hash)
        expect(result[:lines]).to be_an(Array)
        expect(result[:lines].length).to be > 0
        expect(result[:error]).to be_nil
      end

      it "caches the result" do
        # First call
        result1 = helper.read_source_code(frame)

        # Modify file
        File.write(test_file, "modified content")

        # Second call should return cached result
        result2 = helper.read_source_code(frame)

        expect(result1).to eq(result2)
      end

      it "highlights the target line" do
        result = helper.read_source_code(frame)

        highlighted = result[:lines].find { |l| l[:highlight] }
        expect(highlighted[:number]).to eq(6)
        expect(highlighted[:content]).to include('raise "Test error"')
      end
    end

    context "when source code integration is disabled" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = false
      end

      it "returns nil" do
        result = helper.read_source_code(frame)

        expect(result).to be_nil
      end
    end

    context "when file doesn't exist" do
      let(:frame) do
        {
          file_path: "/non/existent/file.rb",
          line_number: 10,
          category: :app
        }
      end

      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
      end

      it "returns error information" do
        result = helper.read_source_code(frame)

        expect(result).to be_a(Hash)
        expect(result[:lines]).to be_nil
        expect(result[:error]).to be_present
      end
    end
  end

  describe "#read_git_blame" do
    let(:frame) do
      {
        file_path: test_file,
        line_number: 6,
        category: :app
      }
    end

    context "when git blame is enabled" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
        RailsErrorDashboard.configuration.enable_git_blame = true

        # Mock git availability
        allow_any_instance_of(RailsErrorDashboard::Services::GitBlameReader)
          .to receive(:git_available?).and_return(true)
      end

      context "with git repository" do
        before do
          # Skip if not in a git repo
          skip "Not in git repository" unless system("git rev-parse --git-dir > /dev/null 2>&1")
        end

        it "returns blame data or nil" do
          result = helper.read_git_blame(frame)

          # May be nil if file not committed, but shouldn't error
          expect(result).to be_a(Hash).or be_nil
        end
      end

      context "without git repository" do
        before do
          allow_any_instance_of(RailsErrorDashboard::Services::GitBlameReader)
            .to receive(:git_available?).and_return(false)
        end

        it "returns nil" do
          result = helper.read_git_blame(frame)

          expect(result).to be_nil
        end
      end
    end

    context "when git blame is disabled" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
        RailsErrorDashboard.configuration.enable_git_blame = false
      end

      it "returns nil" do
        result = helper.read_git_blame(frame)

        expect(result).to be_nil
      end
    end
  end

  describe "#generate_repository_link" do
    let(:frame) do
      {
        file_path: "app/models/user.rb",
        line_number: 42,
        short_path: "app/models/user.rb",
        category: :app
      }
    end

    let(:error_log) do
      double("ErrorLog", git_sha: "abc123def456")
    end

    context "when repository URL is configured" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
        RailsErrorDashboard.configuration.git_repository_url = "https://github.com/user/repo"
        RailsErrorDashboard.configuration.git_branch_strategy = :commit_sha
      end

      it "generates a GitHub link" do
        link = helper.generate_repository_link(frame, error_log)

        expect(link).to be_a(String)
        expect(link).to include("github.com")
        expect(link).to include("app/models/user.rb")
        expect(link).to include("L42")
        expect(link).to include("abc123def456")
      end
    end

    context "when repository URL is not configured" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
        RailsErrorDashboard.configuration.git_repository_url = nil
      end

      it "returns nil" do
        link = helper.generate_repository_link(frame, error_log)

        expect(link).to be_nil
      end
    end

    context "with different branch strategies" do
      before do
        RailsErrorDashboard.configuration.enable_source_code_integration = true
        RailsErrorDashboard.configuration.git_repository_url = "https://github.com/user/repo"
      end

      it "uses commit SHA strategy" do
        RailsErrorDashboard.configuration.git_branch_strategy = :commit_sha

        link = helper.generate_repository_link(frame, error_log)

        expect(link).to include("abc123def456")
      end

      it "uses main branch strategy" do
        RailsErrorDashboard.configuration.git_branch_strategy = :main

        link = helper.generate_repository_link(frame, error_log)

        expect(link).to include("/main/")
      end
    end
  end

  describe "existing helper methods" do
    let(:backtrace_string) do
      "app/models/user.rb:10:in `save'\napp/controllers/users_controller.rb:15:in `create'"
    end

    describe "#parse_backtrace" do
      it "parses backtrace string" do
        frames = helper.parse_backtrace(backtrace_string)

        expect(frames).to be_an(Array)
        expect(frames.length).to be > 0
      end
    end

    describe "#filter_app_code" do
      it "filters app code frames" do
        frames = helper.parse_backtrace(backtrace_string)
        app_frames = helper.filter_app_code(frames)

        expect(app_frames).to all(have_attributes(category: :app))
      end
    end
  end
end
