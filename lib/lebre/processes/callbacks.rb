# frozen_string_literal: true

module Lebre::Processes
  module Callbacks
    def self.included(base)
      base.extend(ClassMethods)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def run_process_callbacks(name)
        self.class.send(:"before_#{name}_callbacks").each do |method|
          send(method)
        end
        yield if block_given?
        self.class.send(:"after_#{name}_callbacks").each do |method|
          send(method)
        end
      end
    end

    module ClassMethods
      def inherited(base)
        base.instance_variable_set(:@before_boot_callbacks, before_boot_callbacks.dup)
        base.instance_variable_set(:@after_boot_callbacks, after_boot_callbacks.dup)
        base.instance_variable_set(:@before_shutdown_callbacks, before_shutdown_callbacks.dup)
        base.instance_variable_set(:@after_shutdown_callbacks, after_shutdown_callbacks.dup)
      end

      def before_boot(*methods)
        @before_boot_callbacks ||= []
        @before_boot_callbacks.concat methods
      end

      def after_boot(*methods)
        @after_boot_callbacks ||= []
        @after_boot_callbacks.concat methods
      end

      def before_shutdown(*methods)
        @before_shutdown_callbacks ||= []
        @before_shutdown_callbacks.concat methods
      end

      def after_shutdown(*methods)
        @after_shutdown_callbacks ||= []
        @after_shutdown_callbacks.concat methods
      end

      def before_boot_callbacks
        @before_boot_callbacks || []
      end

      def after_boot_callbacks
        @after_boot_callbacks || []
      end

      def before_shutdown_callbacks
        @before_shutdown_callbacks || []
      end

      def after_shutdown_callbacks
        @after_shutdown_callbacks || []
      end
    end
  end
end
