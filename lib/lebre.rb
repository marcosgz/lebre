# frozen_string_literal: true

require "bunny"
require "concurrent"
require "fileutils"
require "logger"
require "pathname"
require "securerandom"
require "singleton"
require "socket"
require "time"
require "yaml"
require "zeitwerk"

module Lebre
  DEFAULT_LOGGER = Logger.new($stdout)

  class Error < StandardError
  end

  # Error that is raised when the Bunny recovery attempts are exhausted.
  class MaxRecoveryAttemptsExhaustedError < Error
  end

  # Error that is raised when an invalid value is returned from {#work}
  class InvalidConsumerReturnError < Error
    def initialize(value)
      super(
        "#perform must return :ack, :reject or :requeue, received #{value.inspect} instead",
      )
    end
  end

  class InvalidConsumerConfigError < Error
  end

  module Processes
    class ProcessMissingError < RuntimeError
      def initialize
        super("The process that was running this job no longer exists")
      end
    end

    class ProcessExitError < RuntimeError
      def initialize(status)
        message = "Process pid=#{status.pid} exited unexpectedly."
        if status.exitstatus
          message += " Exited with status #{status.exitstatus}."
        end

        if status.signaled?
          message += " Received unhandled signal #{status.termsig}."
        end

        super(message)
      end
    end

    class ProcessPrunedError < RuntimeError
      def initialize(last_heartbeat_at)
        super("Process was found dead and pruned (last heartbeat at: #{last_heartbeat_at}")
      end
    end
  end

  extend self

  def loader
    @loader ||= Zeitwerk::Loader.for_gem(warn_on_extra_files: false).tap do |loader|
      loader.inflector.inflect "json" => "JSON"
      loader.inflector.inflect "cli" => "CLI"
      loader.ignore("#{__dir__}/rails")
      loader.ignore("#{__dir__}/puma")
      loader.ignore("#{__dir__}/cli")
      loader.ignore("#{__dir__}/middlewares")
    end
  end

  def logger
    @logger ||= DEFAULT_LOGGER
  end

  def logger=(logger)
    @logger = logger
  end

  def instrument(channel, **options, &block)
    if defined?(ActiveSupport::Notifications)
      ActiveSupport::Notifications.instrument("#{channel}.lebre", **options, &block)
    else
      yield(options.dup)
    end
  end

  def eager_load_consumers!
    return false unless Lebre.config.consumers_directory.exist?

    Dir[config.consumers_directory.join("**/*.rb")].map { |path| Pathname.new(path) }.each do |path|
      next unless path.extname == ".rb"

      require(path.expand_path.to_s)
    end
    true
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
  end

  loader.setup
end

if defined?(::Rails)
  require_relative "lebre/rails"
end

# if defined?(Puma)
#   require_relative "lebre/puma/plugin"
# end
