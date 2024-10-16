# frozen_string_literal: true

module Lebre
  class Railtie < ::Rails::Railtie
    config.lebre = ActiveSupport::OrderedOptions.new
    config.lebre.app_executor = nil
    config.lebre.on_thread_error = nil

    initializer "lebre.app_executor", before: :run_prepare_callbacks do |app|
      config.lebre.app_executor ||= app.executor
      if ::Rails.respond_to?(:error) && config.lebre.on_thread_error.nil?
        config.lebre.on_thread_error = ->(exception) { Rails.error.report(exception, handled: false) }
      elsif config.lebre.on_thread_error.nil?
        config.lebre.on_thread_error = ->(exception) { Lebre.logger.error(exception) }
      end

      Lebre.config.app_executor = config.lebre.app_executor
      Lebre.config.on_thread_error = config.lebre.on_thread_error
    end

    initializer "lebre.logger" do
      ActiveSupport.on_load(:lebre) do
        self.logger = ::Rails.logger if logger == Lebre::DEFAULT_LOGGER
      end

      Lebre::LogSubscriber.attach_to :lebre
    end
  end

  # ActiveSupport.run_load_hooks(:lebre, Lebre)
end
