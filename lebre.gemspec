# frozen_string_literal: true

require_relative "lib/lebre/version"

Gem::Specification.new do |spec|
  spec.name = "lebre"
  spec.version = Lebre::VERSION
  spec.authors = ["Marcos G. Zimmermann"]
  spec.email = ["mgzmaster@gmail.com"]

  spec.summary = <<~SUMMARY
    RabbitMQ consumers/producer for ruby applications
  SUMMARY
  spec.description = <<~DESCRIPTION
    RabbitMQ consumers/producer for ruby applicationsd
  DESCRIPTION

  spec.homepage = "https://github.com/marcosgz/lebre"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  raise "RubyGems 2.0 or newer is required to protect against public gem pushes." unless spec.respond_to?(:metadata)

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "https://github.com/marcosgz/lebre/issues"
  spec.metadata["documentation_uri"] = "https://github.com/marcosgz/lebre"
  spec.metadata["source_code_uri"] = "https://github.com/marcosgz/lebre"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir = "exec"
  spec.executables = spec.files.grep(%r{^exec/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bunny", ">= 0.0.0"
  spec.add_dependency "zeitwerk", ">= 0.0.0"
  spec.add_dependency "concurrent-ruby", ">= 0.0.0"

  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "webmock"
end
