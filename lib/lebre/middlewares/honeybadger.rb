# frozen_string_literal: true

module Lebre
  module Middlewares
    # A middleware that automatically wraps {Lebre::Consumer#perform]} in an Honeybadger transaction.
    class Honeybadger < Lebre::Middleware
      # @param [Hash] opts The options for the middleware.
      # @option opts [String] :class_name The name of the class you want to monitor.
      def initialize(class_name:, **)
        super

        @class_name = class_name
      end

      def call(message, app)
        app.call(message)
      rescue => err
        ::Honeybadger.notify(err, context: {class_name: @class_name})
        raise err
      end
    end
  end
end
