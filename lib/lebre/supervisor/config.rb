# frozen_string_literal: true

require "yaml"
require "logger"

module Lebre
  class Supervisor < Processes::Base
    class Config
      class Process < Struct.new(:process_class, :attributes)
        def instantiate
          process_class.new(**attributes)
        end
      end

      attr_accessor :pidfile, :require_file

      def initialize(require_file: nil, pidfile: "tmp/pids/lebre.pid", **kwargs)
        @pidfile = pidfile
        @require_file = require_file
        self.consumers = kwargs[:consumers] if kwargs.key?(:consumers)
      end

      def configured_processes
        consumer_processes
      end

      def consumers=(vals)
        @consumer_processes = nil
        @consumers = Array(vals).map(&:to_s)
      end

      def consumers
        @consumers ||= begin
          Lebre.eager_load_consumers!
          Lebre::Consumer.descendants.reject(&:abstract_class?).map(&:name)
        end
      end

      protected

      def consumer_processes
        @consumer_processes ||= consumers.map do |class_name|
          Process.new(Lebre::Processes::Consumer, {class_name: class_name})
        end
      end
    end
  end
end
