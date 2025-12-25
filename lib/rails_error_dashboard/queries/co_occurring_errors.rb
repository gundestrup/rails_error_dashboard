# frozen_string_literal: true

module RailsErrorDashboard
  module Queries
    # Find errors that occur together in time (co-occurring errors)
    #
    # This query analyzes error occurrences to find patterns of errors
    # that happen within the same time window, which can indicate:
    # - Cascading failures (one error causes another)
    # - Related errors from the same underlying issue
    # - Correlated errors from the same feature/endpoint
    #
    # @example Find errors that occur with NoMethodError
    #   co_occurring = CoOccurringErrors.call(error_log_id: 123, window_minutes: 5)
    #   co_occurring.each do |result|
    #     puts "#{result[:error].error_type} occurred #{result[:frequency]} times together"
    #   end
    class CoOccurringErrors
      # Find co-occurring errors
      #
      # @param error_log_id [Integer] ID of target error
      # @param window_minutes [Integer] Time window in minutes (default: 5)
      # @param min_frequency [Integer] Minimum co-occurrence count (default: 2)
      # @param limit [Integer] Maximum number of results (default: 10)
      # @return [Array<Hash>] Array of {error: ErrorLog, frequency: Integer, avg_delay_seconds: Float}
      def self.call(error_log_id:, window_minutes: 5, min_frequency: 2, limit: 10)
        new(error_log_id, window_minutes: window_minutes, min_frequency: min_frequency, limit: limit).find_co_occurring
      end

      def initialize(error_log_id, window_minutes: 5, min_frequency: 2, limit: 10)
        @error_log_id = error_log_id
        @window_minutes = window_minutes.to_i
        @min_frequency = min_frequency.to_i
        @limit = limit.to_i
      end

      def find_co_occurring
        target_error = ErrorLog.find_by(id: @error_log_id)
        return [] unless target_error

        # Get all occurrences of the target error
        target_occurrences = ErrorOccurrence.where(error_log_id: @error_log_id)
        return [] if target_occurrences.empty?

        # For each occurrence, find other errors in the time window
        co_occurrence_data = Hash.new { |h, k| h[k] = { count: 0, delays: [] } }

        target_occurrences.find_each do |occurrence|
          window = @window_minutes.minutes
          start_time = occurrence.occurred_at - window
          end_time = occurrence.occurred_at + window

          # Find other error occurrences in this time window
          nearby_occurrences = ErrorOccurrence
                                .in_time_window(start_time, end_time)
                                .where.not(error_log_id: @error_log_id)
                                .includes(:error_log)

          nearby_occurrences.each do |nearby|
            error_log_id = nearby.error_log_id
            co_occurrence_data[error_log_id][:count] += 1

            # Calculate delay (negative = before, positive = after target error)
            delay = (nearby.occurred_at - occurrence.occurred_at).to_f
            co_occurrence_data[error_log_id][:delays] << delay
          end
        end

        # Filter by minimum frequency and build results
        results = co_occurrence_data.select { |_id, data| data[:count] >= @min_frequency }.map do |error_log_id, data|
          error = ErrorLog.find(error_log_id)
          avg_delay = data[:delays].sum / data[:delays].size

          {
            error: error,
            frequency: data[:count],
            avg_delay_seconds: avg_delay.round(2)
          }
        end

        # Sort by frequency (most common first) and limit results
        results.sort_by { |r| -r[:frequency] }.first(@limit)
      end
    end
  end
end
