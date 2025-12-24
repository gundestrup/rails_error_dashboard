# frozen_string_literal: true

module RailsErrorDashboard
  module Plugins
    # Example plugin: Audit logging
    # Logs all error dashboard activities to a separate audit log
    #
    # Usage:
    #   RailsErrorDashboard.register_plugin(
    #     RailsErrorDashboard::Plugins::AuditLogPlugin.new(logger: Rails.logger)
    #   )
    #
    class AuditLogPlugin < Plugin
      def initialize(logger: Rails.logger)
        @logger = logger
      end

      def name
        "Audit Logger"
      end

      def description
        "Logs all error dashboard activities for compliance and auditing"
      end

      def version
        "1.0.0"
      end

      def on_error_logged(error_log)
        log_event(
          event: "error_logged",
          error_id: error_log.id,
          error_type: error_log.error_type,
          platform: error_log.platform,
          environment: error_log.environment,
          timestamp: Time.current
        )
      end

      def on_error_recurred(error_log)
        log_event(
          event: "error_recurred",
          error_id: error_log.id,
          error_type: error_log.error_type,
          occurrence_count: error_log.occurrence_count,
          timestamp: Time.current
        )
      end

      def on_error_resolved(error_log)
        log_event(
          event: "error_resolved",
          error_id: error_log.id,
          error_type: error_log.error_type,
          resolved_by: error_log.resolved_by_name,
          resolution_comment: error_log.resolution_comment,
          timestamp: Time.current
        )
      end

      def on_errors_batch_resolved(error_logs)
        log_event(
          event: "errors_batch_resolved",
          count: error_logs.size,
          error_ids: error_logs.map(&:id),
          timestamp: Time.current
        )
      end

      def on_errors_batch_deleted(error_ids)
        log_event(
          event: "errors_batch_deleted",
          count: error_ids.size,
          error_ids: error_ids,
          timestamp: Time.current
        )
      end

      def on_error_viewed(error_log)
        log_event(
          event: "error_viewed",
          error_id: error_log.id,
          error_type: error_log.error_type,
          timestamp: Time.current
        )
      end

      private

      def log_event(data)
        @logger.info("[RailsErrorDashboard Audit] #{data.to_json}")
      end
    end
  end
end
