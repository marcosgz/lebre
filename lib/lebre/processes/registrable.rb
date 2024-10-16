# frozen_string_literal: true

module Lebre::Processes
  module Registrable
    def self.included(base)
      base.send :include, InstanceMethods
      base.class_eval do
        after_boot :register
        after_boot :launch_heartbeat

        before_shutdown :stop_heartbeat
        after_shutdown :deregister
      end
    end

    module InstanceMethods
      def process_id
        process&.id
      end

      private

      attr_accessor :process

      def register
        @process = Lebre::Process.register(
          kind: kind,
          name: name,
          pid: pid,
          hostname: hostname,
          supervisor_id: respond_to?(:supervisor) ? supervisor&.id : nil
        )
      end

      def deregister
        process&.deregister
      end

      def registered?
        !!process
      end

      def launch_heartbeat
        @heartbeat_task = ::Concurrent::TimerTask.new(execution_interval: Lebre.config.process_heartbeat_interval) do
          wrap_in_app_executor { heartbeat }
        end

        @heartbeat_task.add_observer do |_, _, error|
          handle_thread_error(error) if error
        end

        @heartbeat_task.execute
      end

      def stop_heartbeat
        @heartbeat_task&.shutdown
      end

      def heartbeat
        process.heartbeat
      rescue Process::NotFoundError
        self.process = nil
        wake_up
      end
    end
  end
end
