# frozen_string_literal: true

module Lebre
  module Processes
    class Base
      include Callbacks
      include AppExecutor
      include Registrable
      include Interruptible
      include Procline

      attr_reader :name

      def initialize(*)
        @name = generate_name
        @stopped = false
      end

      def kind
        self.class.name.split("::").last
      end

      def hostname
        @hostname ||= Socket.gethostname.force_encoding(Encoding::UTF_8)
      end

      def pid
        @pid ||= ::Process.pid
      end

      def metadata
        {}
      end

      def stop
        @stopped = true
      end

      private

      def generate_name
        [kind.downcase, SecureRandom.hex(10)].join("-")
      end

      def stopped?
        @stopped
      end
    end
  end
end
