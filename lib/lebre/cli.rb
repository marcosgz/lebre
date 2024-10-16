require "thor"

module Lebre
  class CLI < Thor
    method_option :debug, type: :boolean, default: false
    method_option :logfile, type: :string, default: nil
    method_option :pidfile, type: :string, default: nil
    method_option :require_file, type: :string, aliases: "-r", default: nil

    desc "start FirstConsumer,SeconConsumer ... ,NthConsumer", "Run Consumer"
    default_command :start

    def start(consumers = "")
      opts = (@options || {}).transform_keys(&:to_sym)
      unless consumers.empty?
        opts[:consumers] = consumers.split(",").map(&:strip)
      end
      if (logfile = opts.delete(:logfile))
        Lebre.logger = Logger.new(logfile)
      end
      if opts.delete(:debug)
        Lebre.logger.level = Logger::DEBUG
      end
      Lebre::Supervisor.start(**opts)
    end
  end
end
