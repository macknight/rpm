# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

# -*- coding: utf-8 -*-
module NewRelic
  module Agent
    class StatsEngine
      module GCProfiler
        GCSnapshot = Struct.new(:gc_time_s, :gc_call_count)

        def self.init
          return @profiler if @initialized
          @profiler = if RailsBenchProfiler.enabled?
            RailsBenchProfiler.new
          elsif CoreGCProfiler.enabled?
            CoreGCProfiler.new
          end
          @initialized = true
          @profiler
        end

        def self.reset
          @profiler    = nil
          @initialized = nil
        end

        def self.take_snapshot
          init
          if @profiler
            GCSnapshot.new(@profiler.call_time_s, @profiler.call_count)
          else
            nil
          end
        end

        def self.record_delta(start_snapshot, end_snapshot)
          if @profiler && start_snapshot && end_snapshot
            elapsed_gc_time_s = end_snapshot.gc_time_s - start_snapshot.gc_time_s
            record_gc_metric(elapsed_gc_time_s)

            @profiler.reset
            elapsed_gc_time_s
          end
        end

        def self.record_gc_metric(elapsed)
          NewRelic::Agent.instance.stats_engine.record_metrics(gc_metric_name,
                                                               elapsed,
                                                               :scoped => true)
        end

        GC_OTHER = 'GC/Transaction/allOther'.freeze
        GC_WEB   = 'GC/Transaction/allWeb'.freeze

        def self.gc_metric_name
          if NewRelic::Agent::Transaction.recording_web_transaction?
            GC_WEB
          else
            GC_OTHER
          end
        end

        class RailsBenchProfiler
          def self.enabled?
            ::GC.respond_to?(:time) && ::GC.respond_to?(:collections)
          end

          def call_time_s
            ::GC.time.to_f / 1_000_000 # this value is reported in us, so convert to s
          end

          def call_count
            ::GC.collections
          end

          def reset
            ::GC.clear_stats
          end
        end

        class CoreGCProfiler
          def self.enabled?
            NewRelic::LanguageSupport.gc_profiler_enabled?
          end

          def call_time_s
            NewRelic::Agent.instance.monotonic_gc_profiler.total_time_s
          end

          def call_count
            ::GC.count
          end

          # When using GC::Profiler, it's important to periodically call
          # GC::Profiler.clear in order to avoid unbounded growth in the number
          # of GC recordds that are stored. However, we actually do this
          # internally within MonotonicGCProfiler on calls to #total_time_s,
          # so the reset here is a no-op.
          def reset; end
        end
      end
    end
  end
end
