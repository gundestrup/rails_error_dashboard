# frozen_string_literal: true

module RailsErrorDashboard
  module Queries
    # Find cascade patterns for an error (what causes it, what it causes)
    #
    # A cascade is when one error leads to another within a time window.
    # This helps identify root causes vs symptoms.
    #
    # @example
    #   cascades = ErrorCascades.call(error_id: 123)
    #   cascades[:parents]  # Errors that cause this one
    #   cascades[:children] # Errors this one causes
    class ErrorCascades
      def self.call(error_id:, min_probability: 0.5)
        new(error_id, min_probability: min_probability).find_cascades
      end

      def initialize(error_id, min_probability: 0.5)
        @error_id = error_id
        @min_probability = min_probability.to_f
      end

      def find_cascades
        return { parents: [], children: [] } unless defined?(CascadePattern)
        return { parents: [], children: [] } unless CascadePattern.table_exists?

        target_error = ErrorLog.find_by(id: @error_id)
        return { parents: [], children: [] } unless target_error

        {
          parents: find_parent_cascades,
          children: find_child_cascades
        }
      end

      private

      def find_parent_cascades
        # Errors that cause this error (this error is the child)
        CascadePattern
          .by_child(@error_id)
          .where("cascade_probability >= ?", @min_probability)
          .includes(:parent_error)
          .order(cascade_probability: :desc)
          .map do |pattern|
            {
              error: pattern.parent_error,
              frequency: pattern.frequency,
              probability: pattern.cascade_probability,
              avg_delay_seconds: pattern.avg_delay_seconds
            }
          end
      end

      def find_child_cascades
        # Errors caused by this error (this error is the parent)
        CascadePattern
          .by_parent(@error_id)
          .where("cascade_probability >= ?", @min_probability)
          .includes(:child_error)
          .order(cascade_probability: :desc)
          .map do |pattern|
            {
              error: pattern.child_error,
              frequency: pattern.frequency,
              probability: pattern.cascade_probability,
              avg_delay_seconds: pattern.avg_delay_seconds
            }
          end
      end
    end
  end
end
