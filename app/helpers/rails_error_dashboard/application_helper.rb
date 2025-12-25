module RailsErrorDashboard
  module ApplicationHelper
    # Returns Bootstrap color class for error severity
    # @param severity [Symbol] The severity level (:critical, :high, :medium, :low, :info)
    # @return [String] Bootstrap color class (danger, warning, info, secondary)
    def severity_color(severity)
      case severity&.to_sym
      when :critical
        "danger"
      when :high
        "warning"
      when :medium
        "info"
      when :low
        "secondary"
      else
        "secondary"
      end
    end
  end
end
