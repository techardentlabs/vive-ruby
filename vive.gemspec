# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "vive"
  spec.version       = "1.0.0"
  spec.authors       = ["Vive"]
  spec.summary       = "Official Ruby client for the Vive WhatsApp messaging API"
  spec.description   = "Send WhatsApp text, templates, media, quick-reply buttons, list " \
                       "pickers, call-to-action buttons, locations and reactions through " \
                       "the Vive API, and verify inbound webhook signatures."
  spec.homepage      = "https://docs.getvive.ai"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*.rb", "README.md", "USAGE.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => "https://docs.getvive.ai",
    "documentation_uri" => "https://docs.getvive.ai",
    "source_code_uri" => "https://github.com/techardentlabs/vive-ruby",
    "bug_tracker_uri" => "https://github.com/techardentlabs/vive-ruby/issues",
    "rubygems_mfa_required" => "true",
  }
end
