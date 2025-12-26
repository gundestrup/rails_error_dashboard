module RailsErrorDashboard
  module ApplicationHelper
    # Returns Bootstrap color class for error severity
    # Uses Catppuccin Mocha colors in dark theme via CSS variables
    # @param severity [Symbol] The severity level (:critical, :high, :medium, :low, :info)
    # @return [String] Bootstrap color class (danger, warning, info, secondary)
    def severity_color(severity)
      case severity&.to_sym
      when :critical
        "danger"   # Maps to --ctp-red in dark mode
      when :high
        "warning"  # Maps to --ctp-peach in dark mode
      when :medium
        "info"     # Maps to --ctp-blue in dark mode
      when :low
        "secondary" # Maps to --ctp-overlay1 in dark mode
      else
        "secondary"
      end
    end

    # Returns CSS variable for severity color (for inline styles)
    # Useful when you need to set background-color or color directly
    # @param severity [Symbol] The severity level
    # @return [String] CSS variable reference
    def severity_color_var(severity)
      case severity&.to_sym
      when :critical
        "var(--ctp-red)"
      when :high
        "var(--ctp-peach)"
      when :medium
        "var(--ctp-blue)"
      when :low
        "var(--ctp-overlay1)"
      else
        "var(--ctp-overlay1)"
      end
    end

    # Returns platform-specific color class
    # @param platform [String] Platform name (ios, android, web, api)
    # @return [String] CSS color variable
    def platform_color_var(platform)
      case platform&.downcase
      when "ios"
        "var(--platform-ios)"
      when "android"
        "var(--platform-android)"
      when "web"
        "var(--platform-web)"
      when "api"
        "var(--platform-api)"
      else
        "var(--text-color)"
      end
    end
  end
end
