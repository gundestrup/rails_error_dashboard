# frozen_string_literal: true

module RailsErrorDashboard
  module Queries
    # Query object for comparing error metrics across platforms
    #
    # Provides analytics comparing iOS vs Android vs API vs Web platforms:
    # - Error rates and trends
    # - Severity distribution
    # - Resolution times
    # - Top errors per platform
    # - Platform stability scores
    # - Cross-platform errors
    #
    # @example
    #   comparison = PlatformComparison.new(days: 7)
    #   comparison.error_rate_by_platform
    #   # => { "ios" => 150, "android" => 200, "api" => 50, "web" => 100 }
    class PlatformComparison
      attr_reader :days

      # @param days [Integer] Number of days to analyze (default: 7)
      def initialize(days: 7)
        @days = days
        @start_date = days.days.ago
      end

      # Get error count by platform for the time period
      # @return [Hash] Platform name => error count
      def error_rate_by_platform
        ErrorLog
          .where("occurred_at >= ?", @start_date)
          .group(:platform)
          .count
      end

      # Get severity distribution by platform
      # @return [Hash] Platform => { severity => count }
      def severity_distribution_by_platform
        platforms = ErrorLog.distinct.pluck(:platform).compact

        platforms.each_with_object({}) do |platform, result|
          errors = ErrorLog
            .where(platform: platform)
            .where("occurred_at >= ?", @start_date)

          # Calculate severity in Ruby since it's a method, not a column
          severity_counts = Hash.new(0)
          errors.each do |error|
            severity_counts[error.severity] += 1
          end

          result[platform] = severity_counts
        end
      end

      # Get average resolution time by platform
      # @return [Hash] Platform => average hours to resolve
      def resolution_time_by_platform
        platforms = ErrorLog.distinct.pluck(:platform).compact

        platforms.each_with_object({}) do |platform, result|
          resolved_errors = ErrorLog
            .where(platform: platform)
            .where.not(resolved_at: nil)
            .where("occurred_at >= ?", @start_date)

          if resolved_errors.any?
            total_hours = resolved_errors.sum do |error|
              ((error.resolved_at - error.occurred_at) / 3600.0).round(2)
            end
            result[platform] = (total_hours / resolved_errors.count).round(2)
          else
            result[platform] = nil
          end
        end
      end

      # Get top 10 errors for each platform
      # @return [Hash] Platform => Array of error hashes
      def top_errors_by_platform
        platforms = ErrorLog.distinct.pluck(:platform).compact

        platforms.each_with_object({}) do |platform, result|
          result[platform] = ErrorLog
            .where(platform: platform)
            .where("occurred_at >= ?", @start_date)
            .select(:id, :error_type, :message, :occurrence_count, :occurred_at)
            .order(occurrence_count: :desc)
            .limit(10)
            .map do |error|
              {
                id: error.id,
                error_type: error.error_type,
                message: error.message&.truncate(100),
                severity: error.severity, # Calls the method
                occurrence_count: error.occurrence_count,
                occurred_at: error.occurred_at
              }
            end
        end
      end

      # Calculate platform stability score (0-100)
      # Higher score = more stable (fewer errors, faster resolution)
      # @return [Hash] Platform => stability score
      def platform_stability_scores
        platforms = ErrorLog.distinct.pluck(:platform).compact
        error_rates = error_rate_by_platform
        resolution_times = resolution_time_by_platform

        # Find max values for normalization
        max_errors = error_rates.values.max || 1
        max_resolution_time = resolution_times.values.compact.max || 1

        platforms.each_with_object({}) do |platform, result|
          error_count = error_rates[platform] || 0
          avg_resolution = resolution_times[platform] || 0

          # Normalize to 0-1 scale (inverted - lower is better)
          error_score = 1.0 - (error_count.to_f / max_errors)
          resolution_score = avg_resolution.positive? ? 1.0 - (avg_resolution / max_resolution_time) : 1.0

          # Weight: 70% error count, 30% resolution time
          # Convert to 0-100 scale
          result[platform] = ((error_score * 0.7 + resolution_score * 0.3) * 100).round(1)
        end
      end

      # Find errors that occur across multiple platforms
      # @return [Array<Hash>] Errors with their platforms
      def cross_platform_errors
        # Get error types that appear on 2+ platforms
        error_types_with_platforms = ErrorLog
          .where("occurred_at >= ?", @start_date)
          .group(:error_type, :platform)
          .select(:error_type, :platform)
          .having("COUNT(*) > 0")
          .pluck(:error_type, :platform)

        # Group by error_type to find those on multiple platforms
        errors_by_type = error_types_with_platforms.group_by { |error_type, _| error_type }

        errors_by_type
          .select { |_, platforms| platforms.map(&:last).uniq.count > 1 }
          .map do |error_type, platform_pairs|
            platforms = platform_pairs.map(&:last).uniq
            total_count = ErrorLog
              .where(error_type: error_type, platform: platforms)
              .where("occurred_at >= ?", @start_date)
              .sum(:occurrence_count)

            {
              error_type: error_type,
              platforms: platforms.sort,
              total_occurrences: total_count,
              platform_breakdown: platforms.each_with_object({}) do |platform, breakdown|
                breakdown[platform] = ErrorLog
                  .where(error_type: error_type, platform: platform)
                  .where("occurred_at >= ?", @start_date)
                  .sum(:occurrence_count)
              end
            }
          end
          .sort_by { |error| -error[:total_occurrences] }
      end

      # Get daily error trend by platform
      # @return [Hash] Platform => { date => count }
      def daily_trend_by_platform
        platforms = ErrorLog.distinct.pluck(:platform).compact

        platforms.each_with_object({}) do |platform, result|
          result[platform] = ErrorLog
            .where(platform: platform)
            .where("occurred_at >= ?", @start_date)
            .group_by_day(:occurred_at, range: @start_date..Time.current)
            .count
        end
      end

      # Get platform health summary
      # @return [Hash] Platform => health metrics
      def platform_health_summary
        platforms = ErrorLog.distinct.pluck(:platform).compact
        error_rates = error_rate_by_platform
        stability_scores = platform_stability_scores

        platforms.each_with_object({}) do |platform, result|
          total_errors = error_rates[platform] || 0

          # Count critical errors by checking severity method
          critical_errors = ErrorLog
            .where(platform: platform)
            .where("occurred_at >= ?", @start_date)
            .select { |error| error.severity == :critical }
            .count

          unresolved_errors = ErrorLog
            .where(platform: platform, resolved_at: nil)
            .where("occurred_at >= ?", @start_date)
            .count

          resolved_errors = ErrorLog
            .where(platform: platform)
            .where.not(resolved_at: nil)
            .where("occurred_at >= ?", @start_date)
            .count

          resolution_rate = total_errors.positive? ? ((resolved_errors.to_f / total_errors) * 100).round(1) : 0.0

          # Calculate error velocity (increasing or decreasing)
          first_half = ErrorLog
            .where(platform: platform)
            .where("occurred_at >= ? AND occurred_at < ?", @start_date, @start_date + (@days / 2.0).days)
            .count

          second_half = ErrorLog
            .where(platform: platform)
            .where("occurred_at >= ?", @start_date + (@days / 2.0).days)
            .count

          velocity = first_half.positive? ? (((second_half - first_half).to_f / first_half) * 100).round(1) : 0.0

          result[platform] = {
            total_errors: total_errors,
            critical_errors: critical_errors,
            unresolved_errors: unresolved_errors,
            resolution_rate: resolution_rate,
            stability_score: stability_scores[platform] || 0,
            error_velocity: velocity, # Positive = increasing, negative = decreasing
            health_status: determine_health_status(stability_scores[platform] || 0, velocity)
          }
        end
      end

      private

      # Determine health status based on stability score and velocity
      # @param stability_score [Float] 0-100 stability score
      # @param velocity [Float] Error velocity percentage
      # @return [Symbol] :healthy, :warning, or :critical
      def determine_health_status(stability_score, velocity)
        if stability_score >= 80 && velocity <= 10
          :healthy
        elsif stability_score >= 60 && velocity <= 50
          :warning
        else
          :critical
        end
      end
    end
  end
end
