# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # Throttles baseline alerts to prevent alert fatigue
    #
    # Tracks when alerts were last sent for each error_type/platform combination
    # and prevents sending duplicate alerts within the cooldown window.
    #
    # Uses an in-memory cache (class variable) for simplicity. For distributed
    # systems, consider using Redis or a database-backed solution.
    class BaselineAlertThrottler
      @last_alert_times = {}
      @mutex = Mutex.new

      class << self
        # Check if an alert should be sent (not in cooldown period)
        # @param error_type [String] The error type
        # @param platform [String] The platform
        # @param cooldown_minutes [Integer] Cooldown period in minutes
        # @return [Boolean] True if alert should be sent
        def should_alert?(error_type, platform, cooldown_minutes: 120)
          key = alert_key(error_type, platform)

          @mutex.synchronize do
            last_time = @last_alert_times[key]

            # No previous alert, allow this one
            return true if last_time.nil?

            # Check if cooldown period has passed
            Time.current > (last_time + cooldown_minutes.minutes)
          end
        end

        # Record that an alert was sent
        # @param error_type [String] The error type
        # @param platform [String] The platform
        def record_alert(error_type, platform)
          key = alert_key(error_type, platform)

          @mutex.synchronize do
            @last_alert_times[key] = Time.current
          end
        end

        # Get time since last alert
        # @param error_type [String] The error type
        # @param platform [String] The platform
        # @return [Integer, nil] Minutes since last alert, or nil if never alerted
        def minutes_since_last_alert(error_type, platform)
          key = alert_key(error_type, platform)

          @mutex.synchronize do
            last_time = @last_alert_times[key]
            return nil if last_time.nil?

            ((Time.current - last_time) / 60).to_i
          end
        end

        # Clear all alert records (useful for testing)
        def clear!
          @mutex.synchronize do
            @last_alert_times.clear
          end
        end

        # Clean up old entries (older than max_age_hours)
        # Call periodically to prevent memory growth
        # @param max_age_hours [Integer] Remove entries older than this (default: 24)
        def cleanup!(max_age_hours: 24)
          cutoff_time = max_age_hours.hours.ago

          @mutex.synchronize do
            @last_alert_times.delete_if { |_, time| time < cutoff_time }
          end
        end

        private

        def alert_key(error_type, platform)
          "#{error_type}:#{platform}"
        end
      end
    end
  end
end
