require "bunny"

module Lebre
  # Parse the list of options for the consumer.
  class ConsumerConfig
    DEFAULT_EXCHANGE_OPTIONS = {
      name: nil,
      type: :topic, # The type of the exchange (:direct, :fanout, :topic or :headers).
      durable: true
    }.freeze

    DEFAULT_QUEUE_OPTIONS = {
      name: nil,
      durable: true
    }.freeze

    DEFAULT_RETRY_QUEUE_OPTIONS = {
      name: nil,
      durable: true,
      delay: 5000,
      arguments: {}
    }

    DEFAULT_ERROR_QUEUE_OPTIONS = DEFAULT_QUEUE_OPTIONS

    attr_reader :options

    def initialize(options = {})
      opts = HashUtil.deep_symbolize_keys(options)

      @exchange_opts = DEFAULT_EXCHANGE_OPTIONS.merge(
        declaration_config(opts.delete(:exchange))
      )
      @queue_opts = DEFAULT_QUEUE_OPTIONS.merge(
        declaration_config(opts.delete(:queue))
      )
      if (value = opts.delete(:retry_queue))
        @retry_queue_opts = DEFAULT_RETRY_QUEUE_OPTIONS.merge(
          declaration_config(value)
        )
      end
      if (value = opts.delete(:error_queue))
        @error_queue_opts = DEFAULT_ERROR_QUEUE_OPTIONS.merge(
          declaration_config(value)
        )
      end
      @bind_opts = opts.delete(:bind) || {}
      if (routing_key = opts.delete(:routing_key))
        @bind_opts[:routing_key] ||= routing_key
      end
      @options = opts
    end

    def channel_args
      @channel_opts.values_at(
        :consumer_pool_size,
        :consumer_pool_abort_on_exception,
        :consumer_pool_shutdown_timeout
      )
    end

    def exchange_args
      name = @exchange_opts[:name]
      raise InvalidConsumerConfigError, "Exchange name is required" if name.nil?
      [name, @exchange_opts.reject { |k, v| k == :name }]
    end

    def consumer_queue_args
      opts = @queue_opts.reject { |k, v| k == :name }
      return [queue_name, opts] unless retry_queue_args

      opts[:arguments] ||= {}
      opts[:arguments]["x-dead-letter-exchange"] = ""
      opts[:arguments]["x-dead-letter-routing-key"] = retry_queue_name

      [queue_name, opts]
    end

    def retry_queue_args
      return unless @retry_queue_opts

      delay = @retry_queue_opts[:delay]
      args = (@retry_queue_opts[:arguments] || {}).merge(
        "x-dead-letter-exchange" => "",
        "x-dead-letter-routing-key" => queue_name,
        "x-message-ttl" => delay
      )
      extra_keys = %i[name delay]
      opts = @retry_queue_opts.reject { |k, v| extra_keys.include?(k) }
      [retry_queue_name, opts.merge(arguments: args)]
    end

    def error_queue_args
      return unless @error_queue_opts

      name = @error_queue_opts[:name]
      name ||= "#{queue_name}.error"
      [name, @error_queue_opts.reject { |k, v| k == :name }]
    end

    def binds_args
      arguments = @bind_opts.fetch(:arguments, {}).transform_keys(&:to_s)
      opts = {}
      opts[:arguments] = arguments unless arguments.empty?
      if (routing_keys = @bind_opts[:routing_key]).is_a?(Array)
        routing_keys.map { |key| opts.merge(routing_key: key) }
      elsif (routing_key = @bind_opts[:routing_key])
        [opts.merge(routing_key: routing_key)]
      else
        [opts]
      end
    end

    protected

    def queue_name
      name = @queue_opts[:name]
      raise InvalidConsumerConfigError, "Queue name is required" if name.nil?
      name
    end

    def retry_queue_name
      name = @retry_queue_opts[:name]
      name ||= "#{queue_name}.retry"
      name
    end

    # Normalizes a declaration config (for exchanges and queues) into a configuration Hash.
    #
    # If the given `value` is a String, convert it to a Hash with the key `:name` and the value.
    # If the given `value` is a Hash, leave it as is.
    def declaration_config(value)
      case value
      when Hash then value
      when String then {name: value}
      when NilClass then {}
      when TrueClass then {}
      end
    end

    class HashUtil
      def self.deep_symbolize_keys(hash)
        hash.each_with_object({}) do |(k, v), memo|
          memo[k.to_sym] = v.is_a?(Hash) ? deep_symbolize_keys(v) : v
        end
      end
    end
  end
end
