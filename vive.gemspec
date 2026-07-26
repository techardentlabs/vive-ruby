# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "vive"
  spec.version       = "1.0.0"
  spec.authors       = ["Vive"]
  spec.summary       = "Official Ruby client for the Vive WhatsApp messaging API"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"
end
