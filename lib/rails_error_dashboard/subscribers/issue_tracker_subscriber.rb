# frozen_string_literal: true

module RailsErrorDashboard
  module Subscribers
    # Hooks into the error lifecycle to trigger issue tracker jobs.
    #
    # Called from the engine initializer via direct integration with
    # the LogError and ResolveError commands' callback mechanisms.
    #
    # All work is done via background jobs — never blocks the capture path.
    class IssueTrackerSubscriber
      class << self
        # Called when a new error is first logged
        def on_error_logged(error_log)
          return unless should_auto_create?(error_log)
          CreateIssueJob.perform_later(error_log.id)
        rescue => e
          nil
        end

        # Called when a resolved error recurs (auto-reopened)
        def on_error_reopened(error_log)
          return unless error_log.external_issue_url.present?
          return unless RailsErrorDashboard.configuration.enable_issue_tracking
          ReopenLinkedIssueJob.perform_later(error_log.id)
        rescue => e
          nil
        end

        # Called when an existing error occurs again
        def on_error_recurred(error_log)
          return unless error_log.external_issue_url.present?
          return unless RailsErrorDashboard.configuration.enable_issue_tracking
          AddIssueRecurrenceCommentJob.perform_later(error_log.id)
        rescue => e
          nil
        end

        # Called when an error is resolved in the dashboard
        def on_error_resolved(error_log)
          return unless error_log.external_issue_url.present?
          return unless RailsErrorDashboard.configuration.enable_issue_tracking
          CloseLinkedIssueJob.perform_later(error_log.id)
        rescue => e
          nil
        end

        private

        def should_auto_create?(error_log)
          config = RailsErrorDashboard.configuration
          return false unless config.enable_issue_tracking && config.auto_create_issues
          return false if error_log.external_issue_url.present?

          # First occurrence check
          if config.auto_create_issues_on_first_occurrence && error_log.occurrence_count == 1
            return true
          end

          # Severity threshold check
          severity = error_log.severity&.to_sym
          if config.auto_create_issues_for_severities&.include?(severity)
            return true
          end

          false
        end
      end
    end
  end
end
