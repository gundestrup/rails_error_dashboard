# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # Generates links to source code on GitHub, GitLab, or Bitbucket
    # Supports commit SHA, branch, and tag references
    #
    # @example
    #   generator = GithubLinkGenerator.new(
    #     repository_url: "https://github.com/user/repo",
    #     file_path: "app/models/user.rb",
    #     line_number: 42,
    #     commit_sha: "abc123def456"
    #   )
    #   generator.generate_link
    #   # => "https://github.com/user/repo/blob/abc123def456/app/models/user.rb#L42"
    class GithubLinkGenerator
      attr_reader :repository_url, :file_path, :line_number, :commit_sha, :branch, :error

      # Initialize a new link generator
      #
      # @param repository_url [String] Base repository URL (GitHub, GitLab, Bitbucket)
      # @param file_path [String] Relative path to file from repository root
      # @param line_number [Integer] Line number to link to
      # @param commit_sha [String, nil] Git commit SHA (recommended for accuracy)
      # @param branch [String, nil] Branch name (fallback if no commit SHA)
      def initialize(repository_url:, file_path:, line_number:, commit_sha: nil, branch: nil)
        @repository_url = repository_url
        @file_path = file_path
        @line_number = line_number.to_i
        @commit_sha = commit_sha
        @branch = branch || "main"
        @error = nil
      end

      # Generate a link to the source file on the repository host
      #
      # @return [String, nil] URL to the source file or nil if invalid
      def generate_link
        return nil if repository_url.blank? || file_path.blank?

        # Normalize repository URL
        normalized_repo = normalize_repository_url

        # Determine reference (commit SHA or branch)
        reference = determine_reference

        # Generate link based on repository type
        case detect_repository_type
        when :github
          generate_github_link(normalized_repo, reference)
        when :gitlab
          generate_gitlab_link(normalized_repo, reference)
        when :bitbucket
          generate_bitbucket_link(normalized_repo, reference)
        else
          @error = "Unsupported repository type"
          nil
        end
      rescue StandardError => e
        @error = "Error generating link: #{e.message}"
        RailsErrorDashboard::Logger.error("GithubLinkGenerator error for #{repository_url} - #{e.message}")
        nil
      end

      private

      # Normalize repository URL (remove .git suffix, trailing slashes, etc.)
      #
      # @return [String]
      def normalize_repository_url
        url = repository_url.strip
        url = url.chomp(".git")
        url = url.chomp("/")
        url
      end

      # Detect repository type from URL
      #
      # @return [Symbol] :github, :gitlab, :bitbucket, or :unknown
      def detect_repository_type
        normalized = normalize_repository_url.downcase

        return :github if normalized.include?("github.com")
        return :gitlab if normalized.include?("gitlab.com") || normalized.include?("gitlab.")
        return :bitbucket if normalized.include?("bitbucket.org") || normalized.include?("bitbucket.")

        :unknown
      end

      # Determine which reference to use (commit SHA or branch)
      #
      # @return [String]
      def determine_reference
        if commit_sha.present?
          commit_sha
        else
          branch
        end
      end

      # Normalize file path (remove leading slashes, Rails.root prefix, etc.)
      #
      # @return [String]
      def normalize_file_path
        path = file_path.strip

        # Remove leading slash
        path = path.sub(%r{^/}, "")

        # Remove Rails.root or app root prefix if present
        # Handles paths like "/Users/foo/myapp/app/models/user.rb" -> "app/models/user.rb"
        # Match pattern: look for one of the standard Rails directories
        match = path.match(%r{.*/?((?:app|lib|config|db|spec|test)/.*)$})
        if match
          path = match[1]
        end

        path
      end

      # Generate GitHub link
      #
      # Format: https://github.com/user/repo/blob/{ref}/path/to/file.rb#L42
      #
      # @param repo_url [String] Normalized repository URL
      # @param ref [String] Commit SHA or branch name
      # @return [String]
      def generate_github_link(repo_url, ref)
        normalized_path = normalize_file_path
        "#{repo_url}/blob/#{ref}/#{normalized_path}#L#{line_number}"
      end

      # Generate GitLab link
      #
      # Format: https://gitlab.com/user/repo/-/blob/{ref}/path/to/file.rb#L42
      #
      # @param repo_url [String] Normalized repository URL
      # @param ref [String] Commit SHA or branch name
      # @return [String]
      def generate_gitlab_link(repo_url, ref)
        normalized_path = normalize_file_path
        "#{repo_url}/-/blob/#{ref}/#{normalized_path}#L#{line_number}"
      end

      # Generate Bitbucket link
      #
      # Format: https://bitbucket.org/user/repo/src/{ref}/path/to/file.rb#lines-42
      #
      # @param repo_url [String] Normalized repository URL
      # @param ref [String] Commit SHA or branch name
      # @return [String]
      def generate_bitbucket_link(repo_url, ref)
        normalized_path = normalize_file_path
        "#{repo_url}/src/#{ref}/#{normalized_path}#lines-#{line_number}"
      end
    end
  end
end
