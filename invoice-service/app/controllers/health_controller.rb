class HealthController < ApplicationController
  def show
    checks = {
      database: database_check,
      redis: redis_check,
      customer_service: customer_service_check
    }
    
    overall_status = checks.all? { |_, check| check[:status] == 'ok' } ? 'ok' : 'error'
    status_code = overall_status == 'ok' ? :ok : :service_unavailable
    
    render json: {
      status: overall_status,
      timestamp: Time.current.iso8601,
      version: 'invoice-service-v1.0.0',
      checks: checks
    }, status: status_code
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', message: 'Database connected' }
  rescue => e
    { status: 'error', message: e.message }
  end

  def redis_check
    Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:16379')).ping
    { status: 'ok', message: 'Redis connected' }
  rescue => e
    { status: 'error', message: e.message }
  end

  def customer_service_check
    customer_service_url = Rails.application.config.customer_service_url
    response = Faraday.get("#{customer_service_url}/health", nil, { timeout: 5 })
    
    if response.success?
      { status: 'ok', message: 'Customer Service available' }
    else
      { status: 'error', message: "Customer Service returned #{response.status}" }
    end
  rescue => e
    { status: 'error', message: e.message }
  end
end