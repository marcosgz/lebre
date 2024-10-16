# frozen_string_literal: true

module Lebre
  module AppExecutor
    def wrap_in_app_executor(&block)
      if Lebre.config.app_executor
        Lebre.config.app_executor.wrap(&block)
      else
        yield
      end
    end

    def handle_thread_error(error)
      Lebre.instrument(:thread_error, error: error)

      Lebre.config.on_thread_error&.call(error)
    end
  end
end
