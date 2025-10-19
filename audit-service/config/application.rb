require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile
Bundler.require(*Rails.groups)

module AuditService
  class Application < Rails::Application
    # Initialize configuration defaults for Rails 8.0
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties
    config.autoload_lib(ignore: %w[assets tasks])

    # API only mode
    config.api_only = true

    # Time zone
    config.time_zone = 'America/Bogota'

    # Solid Queue configuration
    config.solid_queue.connects_to = { database: { writing: :primary } }

    # Solid Cache configuration
    config.solid_cache.connects_to = { database: { writing: :primary } }

    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ['X-Total-Count', 'X-Page', 'X-Per-Page']
      end
    end

    # Lograge configuration for structured logging
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_options = lambda do |event|
      {
        service: 'audit-service',
        request_id: event.payload[:request_id],
        user_id: event.payload[:user_id],
        ip: event.payload[:ip]
      }
    end

    # PaperTrail configuration for audit trail
    config.paper_trail.enabled = true
    config.paper_trail.version_limit = 50

    # Health check configuration
    config.health_check.standard_checks = %w[database migrations cache]
    config.health_check.include_error_in_response_body = true
  end
end