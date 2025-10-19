require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module InvoiceService
  class Application < Rails::Application
    # Rails 8 configuration
    config.load_defaults 8.0

    # API only
    config.api_only = true

    # Rails 8 - Solid Queue configuration
    config.solid_queue.connects_to = { database: { writing: :queue } }

    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', 
          headers: :any, 
          methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end

    # Timezone
    config.time_zone = 'America/Bogota'

    # Generators configuration
    config.generators do |g|
      g.orm :active_record
      g.test_framework :rspec
      g.factory_bot true
      g.serializer true
    end

    # Invoice Service specific configuration
    config.customer_service_url = ENV.fetch('CUSTOMER_SERVICE_URL', 'http://localhost:3001')
    config.default_currency = 'COP'
    config.tax_rate = 0.19 # IVA 19%
  end
end