# frozen_string_literal: true

module RailsErrorDashboard
  module Queries
    # Query: Aggregate ActiveStorage events from breadcrumbs across all errors
    # Scans error_logs breadcrumbs JSON, filters for "active_storage" category crumbs,
    # and groups by service name with counts by operation type.
    class ActiveStorageSummary
      def self.call(days = 30, application_id: nil)
        new(days, application_id: application_id).call
      end

      def initialize(days = 30, application_id: nil)
        @days = days
        @application_id = application_id
        @start_date = days.days.ago
      end

      def call
        {
          services: aggregated_services
        }
      end

      private

      def base_query
        scope = ErrorLog.where("occurred_at >= ?", @start_date)
                        .where.not(breadcrumbs: nil)
        scope = scope.where(application_id: @application_id) if @application_id.present?
        scope
      end

      def aggregated_services
        results = {}

        base_query.select(:id, :breadcrumbs, :occurred_at).find_each(batch_size: 500) do |error_log|
          crumbs = parse_breadcrumbs(error_log.breadcrumbs)
          next if crumbs.empty?

          as_crumbs = crumbs.select { |c| c["c"] == "active_storage" }
          next if as_crumbs.empty?

          as_crumbs.each do |crumb|
            meta = crumb["meta"] || {}
            service = meta["service"].to_s.presence || "Unknown"
            operation = meta["operation"].to_s

            results[service] ||= {
              service: service,
              upload_count: 0,
              download_count: 0,
              delete_count: 0,
              exist_count: 0,
              error_ids: [],
              durations: [],
              last_seen: nil
            }

            entry = results[service]

            case operation
            when "upload"
              entry[:upload_count] += 1
            when "download", "streaming_download"
              entry[:download_count] += 1
            when "delete", "delete_prefixed"
              entry[:delete_count] += 1
            when "exist"
              entry[:exist_count] += 1
            end

            entry[:durations] << crumb["d"] if crumb["d"].is_a?(Numeric) && crumb["d"] > 0
            entry[:error_ids] << error_log.id
            entry[:last_seen] = [ entry[:last_seen], error_log.occurred_at ].compact.max
          end
        end

        results.values.each do |r|
          r[:error_ids] = r[:error_ids].uniq
          r[:error_count] = r[:error_ids].size
          r[:total_operations] = r[:upload_count] + r[:download_count] + r[:delete_count] + r[:exist_count]
          r[:avg_duration_ms] = r[:durations].any? ? (r[:durations].sum / r[:durations].size).round(2) : nil
          r[:slowest_ms] = r[:durations].max
          r.delete(:durations)
        end
        results.values.sort_by { |r| [ -r[:total_operations], -r[:error_count] ] }
      rescue => e
        Rails.logger.error("[RailsErrorDashboard] ActiveStorageSummary query failed: #{e.class}: #{e.message}")
        []
      end

      def parse_breadcrumbs(raw)
        return [] if raw.blank?
        JSON.parse(raw)
      rescue JSON::ParserError
        []
      end
    end
  end
end
