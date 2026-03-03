# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # Pure algorithm: Capture runtime health metrics at error time
    #
    # Captures GC stats, process RSS memory, thread count, connection pool stats,
    # and Puma stats. NOT memoized — fresh data every call (unlike EnvironmentSnapshot).
    # Every metric call individually wrapped in rescue => nil.
    #
    # Safety contract (from HOST_APP_SAFETY.md):
    # - Total snapshot < 1ms budget
    # - NEVER ObjectSpace.each_object or ObjectSpace.count_objects (heap scan)
    # - NEVER Thread.list.map(&:backtrace) (GVL hold)
    # - Thread.list.count only (O(1), safe)
    # - Process memory: Linux procfs ONLY, no fork/subprocess ever
    # - No new gems, no global state, no Thread.current, no mutex
    class SystemHealthSnapshot
      # Capture current system health metrics
      # @return [Hash] Health snapshot (always safe, never raises)
      def self.capture
        new.capture
      rescue => e
        RailsErrorDashboard::Logger.debug("[RailsErrorDashboard] SystemHealthSnapshot.capture failed: #{e.message}")
        { captured_at: Time.current.iso8601 }
      end

      # @return [Hash] Health snapshot
      def capture
        {
          gc: gc_stats,
          process_memory_mb: process_memory_mb,
          thread_count: thread_count,
          connection_pool: connection_pool_stats,
          puma: puma_stats,
          captured_at: Time.current.iso8601
        }
      end

      private

      def gc_stats
        stats = GC.stat
        {
          heap_live_slots: stats[:heap_live_slots],
          heap_free_slots: stats[:heap_free_slots],
          major_gc_count: stats[:major_gc_count],
          total_allocated_objects: stats[:total_allocated_objects]
        }
      rescue => e
        nil
      end

      def process_memory_mb
        # Linux ONLY — procfs read, no fork, ~0.01ms
        return nil unless File.exist?("/proc/self/status")
        content = File.read("/proc/self/status")
        match = content.match(/VmRSS:\s+(\d+)\s+kB/)
        return nil unless match
        (match[1].to_i / 1024.0).round(1)
      rescue => e
        nil
      end

      def thread_count
        Thread.list.count  # O(1), safe — NEVER .map(&:backtrace)
      rescue => e
        nil
      end

      def connection_pool_stats
        pool = ActiveRecord::Base.connection_pool
        stat = pool.stat
        { size: stat[:size], busy: stat[:busy], dead: stat[:dead],
          idle: stat[:idle], waiting: stat[:waiting] }
      rescue => e
        nil  # Pool may be closed during shutdown
      end

      def puma_stats
        return nil unless defined?(Puma) && Puma.respond_to?(:stats)
        raw = JSON.parse(Puma.stats)
        { pool_capacity: raw["pool_capacity"], max_threads: raw["max_threads"],
          running: raw["running"], backlog: raw["backlog"] }
      rescue => e
        nil
      end
    end
  end
end
