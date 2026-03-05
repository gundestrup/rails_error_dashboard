# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # TracePoint lifecycle manager for capturing local variables at raise time
    #
    # Uses TracePoint(:raise) which only fires when exceptions are raised (rare
    # in normal request flow). Sentry ships this in production (proven safe).
    #
    # Safety contract:
    # - Default OFF (opt-in via config.enable_local_variables = true)
    # - Never stores Binding objects — extracts vars immediately in callback
    # - Every callback wrapped in rescue => e (never raises)
    # - Per-variable rescue in extraction
    # - Skips SystemExit, SignalException, Interrupt
    # - Skips non-app-code paths (gems, vendor, stdlib, this gem)
    # - Re-raise guard: skips if exception already has @_red_locals
    class LocalVariableCapturer
      # Instance variable name used to attach locals to the exception
      LOCALS_IVAR = :@_red_locals

      class << self
        # Enable the TracePoint(:raise) hook globally
        def enable!
          return if enabled?

          @tracepoint = TracePoint.new(:raise) do |tp|
            on_raise(tp)
          rescue => e
            # CRITICAL: never let the callback crash the app
            RailsErrorDashboard::Logger.debug(
              "[RailsErrorDashboard] LocalVariableCapturer callback error: #{e.class} - #{e.message}"
            )
          end

          @tracepoint.enable
        end

        # Disable the TracePoint hook
        def disable!
          @tracepoint&.disable
          @tracepoint = nil
        end

        # Check if currently enabled
        def enabled?
          @tracepoint&.enabled? == true
        end

        # Extract captured locals from an exception (if any)
        # @param exception [Exception] The exception to check
        # @return [Hash, nil] Raw locals hash or nil
        def extract(exception)
          return nil unless exception.is_a?(Exception)
          return nil unless exception.instance_variable_defined?(LOCALS_IVAR)

          exception.instance_variable_get(LOCALS_IVAR)
        rescue => e
          RailsErrorDashboard::Logger.debug(
            "[RailsErrorDashboard] LocalVariableCapturer.extract failed: #{e.message}"
          )
          nil
        end

        private

        # TracePoint callback — runs on every :raise event
        # Filter chain ordered cheapest-first for minimal overhead
        def on_raise(tp)
          exception = tp.raised_exception

          # 1. Skip if already captured (re-raise guard)
          return if exception.instance_variable_defined?(LOCALS_IVAR)

          # 2. Skip system/signal exceptions
          return if exception.is_a?(SystemExit) || exception.is_a?(SignalException) || exception.is_a?(Interrupt)

          # 3. Skip non-app-code paths
          path = tp.path.to_s
          return if skip_path?(path)

          # 4. Extract local variables from the binding
          locals = extract_locals(tp.binding)

          # 5. Attach to exception (never stores the Binding itself)
          exception.instance_variable_set(LOCALS_IVAR, locals) if locals && locals.any?
        end

        # Check if the path should be skipped (gem code, vendor, stdlib, this gem)
        def skip_path?(path)
          path.include?("/gems/") ||
            path.include?("/vendor/") ||
            path.include?("/ruby/") ||
            path.include?("rails_error_dashboard") ||
            path.start_with?("<") # eval, irb, etc.
        end

        # Extract local variables from a binding (per-variable rescue)
        # @param binding_obj [Binding] The binding at raise time
        # @return [Hash] { variable_name_symbol => raw_value }
        def extract_locals(binding_obj)
          return nil unless binding_obj

          var_names = binding_obj.local_variables
          return nil if var_names.empty?

          locals = {}
          var_names.each do |name|
            locals[name] = binding_obj.local_variable_get(name)
          rescue => e
            locals[name] = "(extraction error: #{e.class.name})"
          end

          locals
        rescue => e
          RailsErrorDashboard::Logger.debug(
            "[RailsErrorDashboard] extract_locals failed: #{e.message}"
          )
          nil
        end
      end
    end
  end
end
