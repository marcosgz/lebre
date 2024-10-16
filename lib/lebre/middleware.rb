# frozen_string_literal: true

module Lebre
  # The abstract base class for middlewares.
  # @abstract Subclass and override {#call} (and maybe +#initialize+) to implement.
  class Middleware
    def initialize(**)
    end

    # Invokes the middleware.
    #
    # @param [Lebre::Message] message The message to process.
    # @param app The next middleware to call or the actual consumer instance.
    def call(message, app)
      raise NotImplementedError
    end
  end
end
