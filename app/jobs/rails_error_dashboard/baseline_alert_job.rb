# frozen_string_literal: true

module RailsErrorDashboard
  # Sends baseline anomaly alerts through configured notification channels
  #
  # This job is triggered when an error exceeds baseline thresholds.
  # It respects cooldown periods to prevent alert fatigue and sends
  # notifications through all enabled channels (Slack, Email, Discord, etc.)
  class BaselineAlertJob < ApplicationJob
    queue_as :default

    # @param error_log_id [Integer] The error log that triggered the alert
    # @param anomaly_data [Hash] Anomaly information from baseline check
    def perform(error_log_id, anomaly_data)
      error_log = ErrorLog.find_by(id: error_log_id)
      return unless error_log

      config = RailsErrorDashboard.configuration

      # Check if we should send alert (cooldown check)
      unless Services::BaselineAlertThrottler.should_alert?(
        error_log.error_type,
        error_log.platform,
        cooldown_minutes: config.baseline_alert_cooldown_minutes
      )
        Rails.logger.info(
          "Baseline alert throttled for #{error_log.error_type} on #{error_log.platform}"
        )
        return
      end

      # Record that we're sending an alert
      Services::BaselineAlertThrottler.record_alert(
        error_log.error_type,
        error_log.platform
      )

      # Send notifications through all enabled channels
      send_notifications(error_log, anomaly_data, config)
    end

    private

    def send_notifications(error_log, anomaly_data, config)
      # Slack notification
      if config.enable_slack_notifications && config.slack_webhook_url.present?
        send_slack_notification(error_log, anomaly_data, config)
      end

      # Email notification
      if config.enable_email_notifications && config.notification_email_recipients.any?
        send_email_notification(error_log, anomaly_data, config)
      end

      # Discord notification
      if config.enable_discord_notifications && config.discord_webhook_url.present?
        send_discord_notification(error_log, anomaly_data, config)
      end

      # Webhook notification
      if config.enable_webhook_notifications && config.webhook_urls.any?
        send_webhook_notification(error_log, anomaly_data, config)
      end

      # PagerDuty for critical anomalies
      if config.enable_pagerduty_notifications &&
         config.pagerduty_integration_key.present? &&
         anomaly_data[:level] == :critical
        send_pagerduty_notification(error_log, anomaly_data, config)
      end
    end

    def send_slack_notification(error_log, anomaly_data, config)
      payload = build_slack_payload(error_log, anomaly_data, config)

      HTTParty.post(
        config.slack_webhook_url,
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    rescue => e
      Rails.logger.error("Failed to send baseline alert to Slack: #{e.message}")
    end

    def send_email_notification(error_log, _anomaly_data, _config)
      # Use existing email notification infrastructure if available
      # For now, log that email would be sent
      Rails.logger.info(
        "Baseline alert email would be sent for #{error_log.error_type}"
      )
    rescue => e
      Rails.logger.error("Failed to send baseline alert email: #{e.message}")
    end

    def send_discord_notification(error_log, anomaly_data, config)
      payload = build_discord_payload(error_log, anomaly_data, config)

      HTTParty.post(
        config.discord_webhook_url,
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    rescue => e
      Rails.logger.error("Failed to send baseline alert to Discord: #{e.message}")
    end

    def send_webhook_notification(error_log, anomaly_data, config)
      payload = build_webhook_payload(error_log, anomaly_data)

      config.webhook_urls.each do |url|
        HTTParty.post(
          url,
          body: payload.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end
    rescue => e
      Rails.logger.error("Failed to send baseline alert to webhook: #{e.message}")
    end

    def send_pagerduty_notification(error_log, _anomaly_data, _config)
      # Use existing PagerDuty notification infrastructure if available
      Rails.logger.info(
        "Baseline alert PagerDuty notification for #{error_log.error_type}"
      )
    rescue => e
      Rails.logger.error("Failed to send baseline alert to PagerDuty: #{e.message}")
    end

    # Build Slack message payload
    def build_slack_payload(error_log, anomaly_data, config)
      {
        text: "🚨 Baseline Anomaly Alert",
        blocks: [
          {
            type: "header",
            text: {
              type: "plain_text",
              text: "🚨 Baseline Anomaly Detected"
            }
          },
          {
            type: "section",
            fields: [
              {
                type: "mrkdwn",
                text: "*Error Type:*\n#{error_log.error_type}"
              },
              {
                type: "mrkdwn",
                text: "*Platform:*\n#{error_log.platform}"
              },
              {
                type: "mrkdwn",
                text: "*Severity:*\n#{anomaly_level_emoji(anomaly_data[:level])} #{anomaly_data[:level].to_s.upcase}"
              },
              {
                type: "mrkdwn",
                text: "*Standard Deviations:*\n#{anomaly_data[:std_devs_above]&.round(1)}σ above baseline"
              }
            ]
          },
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*Message:*\n```#{error_log.message.truncate(200)}```"
            }
          },
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*Baseline Info:*\nThreshold: #{anomaly_data[:threshold]&.round(1)} errors\nBaseline Type: #{anomaly_data[:baseline_type]}"
            }
          },
          {
            type: "actions",
            elements: [
              {
                type: "button",
                text: {
                  type: "plain_text",
                  text: "View in Dashboard"
                },
                url: dashboard_url(error_log, config)
              }
            ]
          }
        ]
      }
    end

    # Build Discord embed payload
    def build_discord_payload(error_log, anomaly_data, config)
      {
        embeds: [
          {
            title: "🚨 Baseline Anomaly Detected",
            color: anomaly_color(anomaly_data[:level]),
            fields: [
              { name: "Error Type", value: error_log.error_type, inline: true },
              { name: "Platform", value: error_log.platform, inline: true },
              { name: "Severity", value: anomaly_data[:level].to_s.upcase, inline: true },
              { name: "Standard Deviations", value: "#{anomaly_data[:std_devs_above]&.round(1)}σ above baseline", inline: true },
              { name: "Threshold", value: "#{anomaly_data[:threshold]&.round(1)} errors", inline: true },
              { name: "Baseline Type", value: anomaly_data[:baseline_type] || "N/A", inline: true },
              { name: "Message", value: "```#{error_log.message.truncate(200)}```", inline: false }
            ],
            url: dashboard_url(error_log, config),
            timestamp: Time.current.iso8601
          }
        ]
      }
    end

    # Build generic webhook payload
    def build_webhook_payload(error_log, anomaly_data)
      {
        event: "baseline_anomaly",
        timestamp: Time.current.iso8601,
        error: {
          id: error_log.id,
          type: error_log.error_type,
          message: error_log.message,
          platform: error_log.platform,
          severity: error_log.severity.to_s,
          occurred_at: error_log.occurred_at.iso8601
        },
        anomaly: {
          level: anomaly_data[:level].to_s,
          std_devs_above: anomaly_data[:std_devs_above],
          threshold: anomaly_data[:threshold],
          baseline_type: anomaly_data[:baseline_type]
        },
        dashboard_url: dashboard_url(error_log, RailsErrorDashboard.configuration)
      }
    end

    def anomaly_level_emoji(level)
      case level
      when :critical then "🔴"
      when :high then "🟠"
      when :elevated then "🟡"
      else "⚪"
      end
    end

    def anomaly_color(level)
      case level
      when :critical then 15158332 # Red
      when :high then 16744192 # Orange
      when :elevated then 16776960 # Yellow
      else 9807270 # Gray
      end
    end

    def dashboard_url(error_log, config)
      base_url = config.dashboard_base_url || "http://localhost:3000"
      "#{base_url}/error_dashboard/errors/#{error_log.id}"
    end
  end
end
