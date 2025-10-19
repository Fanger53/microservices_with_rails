class HealthController < ApplicationController
  # Health check endpoint - no authentication required
  skip_before_action :authenticate_request, only: [:check, :detailed]
  
  def check
    render json: {
      status: 'healthy',
      service: 'api-gateway',
      timestamp: Time.current.iso8601,
      version: '1.0.0'
    }
  end
  
  def detailed
    start_time = Time.current
    
    services_health = check_services_health
    
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    overall_status = services_health.values.all? { |status| status[:healthy] } ? 'healthy' : 'degraded'
    
    render json: {
      status: overall_status,
      service: 'api-gateway',
      timestamp: Time.current.iso8601,
      version: '1.0.0',
      response_time_ms: response_time,
      services: services_health,
      dependencies: {
        database: check_database_health,
        redis: check_redis_health
      }
    }
  end
  
  private
  
  def check_services_health
    services = {
      customer_service: Rails.application.config.x.services.customer_service.base_url,
      invoice_service: Rails.application.config.x.services.invoice_service.base_url,
      audit_service: Rails.application.config.x.services.audit_service.base_url
    }
    
    health_results = {}
    
    services.each do |service_name, base_url|
      health_results[service_name] = check_service_health(service_name, base_url)
    end
    
    health_results
  end
  
  def check_service_health(service_name, base_url)
    start_time = Time.current
    
    begin
      conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json
        f.adapter :net_http
        f.options.timeout = 5
        f.options.open_timeout = 2
      end
      
      response = conn.get('/health')
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if response.success?
        {
          healthy: true,
          status: 'UP',
          response_time_ms: response_time,
          last_checked: Time.current.iso8601
        }
      else
        {
          healthy: false,
          status: 'DOWN',
          response_time_ms: response_time,
          error: "HTTP #{response.status}",
          last_checked: Time.current.iso8601
        }
      end
    rescue => e
      response_time = ((Time.current - start_time) * 1000).round(2)
      {
        healthy: false,
        status: 'DOWN',
        response_time_ms: response_time,
        error: e.message,
        last_checked: Time.current.iso8601
      }
    end
  end
  
  def check_database_health
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      { healthy: true, status: 'UP' }
    rescue => e
      { healthy: false, status: 'DOWN', error: e.message }
    end
  end
  
  def check_redis_health
    return { healthy: true, status: 'SKIPPED', message: 'Redis not configured' } unless defined?(Redis)
    
    begin
      if Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
        Rails.cache.redis.ping
        { healthy: true, status: 'UP' }
      else
        { healthy: true, status: 'SKIPPED', message: 'Redis cache not configured' }
      end
    rescue => e
      { healthy: false, status: 'DOWN', error: e.message }
    end
  end
end