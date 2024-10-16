# frozen_string_literal: true

module Lebre
  # The class representing the global {Lebre} configuration.
  class Configuration
    DEFAULT_RABBITMQ_URL = "amqp://guest:guest@localhost:5672"
    DEFAULT_RECOVERY_ATTEMPTS = 10
    DEFAULT_RECOVER_FROM_CONNECTION_CLOSE = true
    DEFAULT_CONSUMERS_DIRECTORY = Pathname.new("app/consumers")

    # @return [String] the connection string for RabbitMQ.
    attr_accessor :rabbitmq_url

    # @return [String] the name for the RabbitMQ connection.
    attr_accessor :connection_name

    # @return [Boolean] if the recover_from_connection_close value is set for the RabbitMQ connection.
    attr_accessor :recover_from_connection_close

    # @return [Integer] max number of recovery attempts, nil means forever
    attr_accessor :recovery_attempts

    # @return [Pathname] the directory where the consumers are stored.
    attr_reader :consumers_directory

    # @return [Class] the Rails executor used to wrap asynchronous operations, defaults to the app executor
    # @see https://guides.rubyonrails.org/threading_and_code_execution.html#executor
    attr_accessor :app_executor

    # @return [Proc] custom lambda/Proc to call when there's an error within a Lebre thread that takes the exception raised as argument
    attr_accessor :on_thread_error

    # @return [Integer] the interval in seconds between heartbeats. Default is 60 seconds.
    attr_accessor :process_heartbeat_interval

    # @return [Integer] the threshold in seconds to consider a process alive. Default is 5 minutes.
    attr_accessor :process_alive_threshold

    def initialize
      @connection_name = "Lebre (#{Lebre::VERSION})"
      @rabbitmq_url = ENV.fetch("RABBITMQ_URL", DEFAULT_RABBITMQ_URL) || DEFAULT_RABBITMQ_URL
      @recovery_attempts = DEFAULT_RECOVERY_ATTEMPTS
      @recover_from_connection_close = DEFAULT_RECOVER_FROM_CONNECTION_CLOSE
      @consumers_directory = DEFAULT_CONSUMERS_DIRECTORY
      @process_heartbeat_interval = 60
      @process_alive_threshold = 5 * 60
    end

    def create_connection(suffix: nil)
      kwargs = connection_config
      if suffix && connection_name
        kwargs[:connection_name] = "#{connection_name} #{suffix}"
      end
      ::Bunny
        .new(rabbitmq_url, **kwargs)
        .tap { |conn| conn.start }
    end

    def consumers_directory=(value)
      @consumers_directory = value.is_a?(Pathname) ? value : Pathname.new(value)
    end

    protected

    def connection_config
      {
        connection_name: connection_name,
        recover_from_connection_close: recover_from_connection_close,
        recovery_attempts: recovery_attempts,
        recovery_attempts_exhausted: recovery_attempts_exhausted
      }.compact
    end

    # @return [Proc] that is passed to Bunny’s recovery_attempts_exhausted block. Nil if recovery_attempts is nil.
    def recovery_attempts_exhausted
      return nil unless recovery_attempts

      proc do
        # We need to have this since Bunny’s multi-threading is cumbersome here.
        # Session reconnection seems not to be done in the main thread. If we want to
        # achieve a restart of the app we need to modify the thread behaviour.
        Thread.current.abort_on_exception = true
        raise Lebre::MaxRecoveryAttemptsExhaustedError
      end
    end
  end
end
