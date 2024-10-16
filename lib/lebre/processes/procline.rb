# frozen_string_literal: true

module Lebre::Processes
  module Procline
    # Sets the procline ($0)
    # lebre-supervisor(0.1.0): <string>
    def procline(string)
      $0 = "lebre-#{self.class.name.split("::").last.downcase}: #{string}"
    end
  end
end
