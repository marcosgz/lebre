# frozen_string_literal: true

module Lebre::Processes
  module Supervised
    def self.included(base)
      base.send :include, InstanceMethods
      base.class_eval do
        attr_reader :supervisor
      end
    end

    module InstanceMethods
      def supervised_by(process)
        @supervisor = process
      end

      private

      def set_procline
        procline "waiting"
      end

      def supervisor_went_away?
        supervised? && supervisor.pid != ::Process.ppid
      end

      def supervised?
        !!supervisor
      end

      def register_signal_handlers
        %w[INT TERM].each do |signal|
          trap(signal) do
            stop
          end
        end

        trap(:QUIT) do
          exit!
        end
      end
    end
  end
end
