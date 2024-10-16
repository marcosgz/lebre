# frozen_string_literal: true

module Lebre::Processes
  class Consumer < Base
    include Runnable

    attr_reader :consumer_class

    def initialize(class_name:, **options)
      @consumer_class = class_name
      @consumer_class = @consumer_class.constantize if @consumer_class.is_a?(String)
      super(**options)
    end

    def metadata
      super.merge(consumer_class: consumer_class.to_s)
    end

    private

    SLEEP_INTERVAL = 5

    def run
      wrap_in_app_executor do
        setup_consumer! # initialize bunny consumer within the #run method to ensure the process is running in the correct thread
      end

      loop do
        break if shutting_down?

        wrap_in_app_executor do
          interruptible_sleep(SLEEP_INTERVAL)
        end
      end
    ensure
      Lebre.instrument(:shutdown_process, process: self) do
        run_process_callbacks(:shutdown) { shutdown }
      end
    end

    def shutdown
      @consumers.to_a.each(&:cancel)
      @channel&.close
      @bunny&.close

      super
    end

    def setup_consumer!
      @bunny = Thread.current[:lebre_bunny] || Lebre.config.create_connection
      @channel = Thread.current[:lebre_channel] || begin
        @bunny.create_channel(nil, 1, true).tap do |channel|
          channel.prefetch(1)
          channel.on_uncaught_exception { |error| handle_thread_error(error) }
        end
      end

      @exchange = @channel.exchange(*consumer_class.config.exchange_args)
      if (args = consumer_class.config.retry_queue_args)
        @retry_queue = @channel.queue(*args)
      end
      if (args = consumer_class.config.error_queue_args)
        @error_queue = @channel.queue(*args)
      end

      @consumers = Array.new((_threads = 1)) do |n| # may add multiple consumers in the future, need to test how this works
        main_queue = @channel.queue(*consumer_class.config.consumer_queue_args)
        consumer_class.config.binds_args.each do |opts|
          main_queue.bind(@exchange, **opts)
        end

        consumer_wrapper = Lebre::ConsumerWrapper.new(
          consumer_class.new,
          main_queue.channel,
          main_queue,
          "#{consumer_class.name}-#{n + 1}"
        )
        consumer_wrapper.on_delivery do |delivery_info, metadata, payload|
          consumer_wrapper.process_delivery(delivery_info, metadata, payload)
        end
        main_queue.subscribe_with(consumer_wrapper)
      end
      # rescue Lebre::InvalidConsumerConfigError => e
      #   # shutdown if the consumer config is invalid
      #   raise e
    end
  end
end
