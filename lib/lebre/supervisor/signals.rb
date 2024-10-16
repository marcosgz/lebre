# frozen_string_literal: true

module Lebre
  class Supervisor < Processes::Base
    module Signals
      def self.included(base)
        base.send :include, InstanceMethods
        base.class_eval do
          before_boot :register_signal_handlers
          after_shutdown :restore_default_signal_handlers
        end
      end

      module InstanceMethods
        private

        SIGNALS = %i[QUIT INT TERM]

        def register_signal_handlers
          SIGNALS.each do |signal|
            trap(signal) do
              signal_queue << signal
              interrupt
            end
          end
        end

        def restore_default_signal_handlers
          SIGNALS.each do |signal|
            trap(signal, :DEFAULT)
          end
        end

        def process_signal_queue
          while (signal = signal_queue.shift)
            handle_signal(signal)
          end
        end

        def handle_signal(signal)
          case signal
          when :TERM, :INT
            stop
            terminate_gracefully
          when :QUIT
            stop
            terminate_immediately
          else
            Lebre.instrument :unhandled_signal_error, signal: signal
          end
        end

        def signal_processes(pids, signal)
          pids.each do |pid|
            signal_process pid, signal
          end
        end

        def signal_process(pid, signal)
          ::Process.kill signal, pid
        rescue Errno::ESRCH
          # Ignore, process died before
        end

        def signal_queue
          @signal_queue ||= []
        end
      end
    end
  end
end
