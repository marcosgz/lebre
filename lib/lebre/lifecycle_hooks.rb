# frozen_string_literal: true

module Lebre
  module LifecycleHooks
    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
      base.instance_variable_set(:@lifecycle_hooks, {start: [], stop: []})
    end

    module ClassMethods
      attr_reader :lifecycle_hooks

      def on_start(&block)
        lifecycle_hooks[:start] << block
      end

      def on_stop(&block)
        lifecycle_hooks[:stop] << block
      end

      def clear_hooks
        lifecycle_hooks[:start] = []
        lifecycle_hooks[:stop] = []
      end
    end

    module InstanceMethods
      private

      def run_start_hooks
        run_hooks_for :start
      end

      def run_stop_hooks
        run_hooks_for :stop
      end

      def run_hooks_for(event)
        self.class.lifecycle_hooks.fetch(event, []).each do |block|
          block.call
        rescue Exception => exception # rubocop:disable Lint/RescueException
          handle_thread_error(exception)
        end
      end
    end
  end
end
