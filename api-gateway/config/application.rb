require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile
Bundler.require(*Rails.groups)

module ApiGateway
  class Application < Rails::Application
    # Initialize configuration defaults for Rails 8.0
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties
    config.autoload_lib(ignore: %w[assets tasks])

    # API only mode for gateway
    config.api_only = true

    # Time zone
    config.time_zone = 'America/Bogota'

    # Solid Queue configuration
    config.solid_queue.connects_to = { database: { writing: :primary } }

    # Solid Cache configuration
    config.solid_cache.connects_to = { database: { writing: :primary } }

    # CORS configuration - más permisivo para el gateway
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*' # En producción, especificar dominios exactos
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ['X-Total-Count', 'X-Page', 'X-Per-Page', 'X-Gateway-Version', 'X-Service-Response-Time']
      end
    end

    # Rack Attack para rate limiting
    config.middleware.use Rack::Attack

    # Timeout para requests
    config.middleware.use Rack::Timeout, service_timeout: 30

    # Lograge configuration para structured logging
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_options = lambda do |event|
      {
        gateway: 'api-gateway',
        version: '1.0.0',
        request_id: event.payload[:request_id],
        user_id: event.payload[:user_id],
        target_service: event.payload[:target_service],
        proxy_duration_ms: event.payload[:proxy_duration_ms],
        ip: event.payload[:ip],
        user_agent: event.payload[:user_agent]
      }
    end

    # Health check configuration
    config.health_check.standard_checks = %w[database cache]
    config.health_check.include_error_in_response_body = true

    # Gateway specific configurations
    config.x.services = {
      customer: {
        url: ENV['CUSTOMER_SERVICE_URL'] || 'http://customer-service:3001',
        timeout: 10,
        retries: 3,
        circuit_breaker: {
          failure_threshold: 5,
          recovery_timeout: 30
        }
      },
      invoice: {
        url: ENV['INVOICE_SERVICE_URL'] || 'http://invoice-service:3002',
        timeout: 15,
        retries: 3,
        circuit_breaker: {
          failure_threshold: 5,
          recovery_timeout: 30
        }
      },
      audit: {
        url: ENV['AUDIT_SERVICE_URL'] || 'http://audit-service:3003',
        timeout: 20,
        retries: 2,
        circuit_breaker: {
          failure_threshold: 10,
          recovery_timeout: 60
        }
      }
    }

    # JWT configuration
    config.x.jwt = {
      secret: ENV['JWT_SECRET'] || Rails.application.secret_key_base,
      algorithm: 'HS256',
      expiration: 24.hours.to_i
    }

    # Rate limiting configuration
    config.x.rate_limiting = {
      requests_per_minute: 100,
      requests_per_hour: 1000,
      burst_requests: 20
    }
  end
end