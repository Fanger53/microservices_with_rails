class HealthController < ApplicationController
  # Health check endpoint para load balancer y monitoreo
  def check
    health_status = {
      status: 'healthy',
      service: 'audit-service',
      version: '1.0.0',
      timestamp: Time.current.iso8601,
      checks: {}
    }

    begin
      # Check database connectivity
      health_status[:checks][:database] = check_database
      
      # Check Redis connectivity
      health_status[:checks][:redis] = check_redis
      
      # Check other services connectivity
      health_status[:checks][:external_services] = check_external_services
      
      # Check storage/disk space
      health_status[:checks][:storage] = check_storage
      
      # Overall health status
      all_healthy = health_status[:checks].values.all? { |check| check[:status] == 'healthy' }
      health_status[:status] = all_healthy ? 'healthy' : 'degraded'
      
      status_code = all_healthy ? :ok : :service_unavailable
      
      render json: health_status, status: status_code
      
    rescue => e
      health_status[:status] = 'unhealthy'
      health_status[:error] = e.message
      health_status[:checks][:error] = {
        status: 'unhealthy',
        message: e.message,
        timestamp: Time.current.iso8601
      }
      
      render json: health_status, status: :service_unavailable
    end
  end

  private

  def check_database
    start_time = Time.current
    
    begin
      # Simple query to check database
      AuditLog.connection.execute('SELECT 1')
      AuditLog.limit(1).count # Test active record
      
      {
        status: 'healthy',
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        message: 'Database connection successful',
        timestamp: Time.current.iso8601
      }
    rescue => e
      {
        status: 'unhealthy',
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        message: "Database connection failed: #{e.message}",
        timestamp: Time.current.iso8601
      }
    end
  end

  def check_redis
    start_time = Time.current
    
    begin
      # Test Redis connection
      Rails.cache.write('health_check', Time.current.to_i, expires_in: 30.seconds)
      cached_value = Rails.cache.read('health_check')
      
      if cached_value
        {
          status: 'healthy',
          response_time_ms: ((Time.current - start_time) * 1000).round(2),
          message: 'Redis connection successful',
          timestamp: Time.current.iso8601
        }
      else
        {
          status: 'unhealthy',
          response_time_ms: ((Time.current - start_time) * 1000).round(2),
          message: 'Redis read/write test failed',
          timestamp: Time.current.iso8601
        }
      end
    rescue => e
      {
        status: 'unhealthy',
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        message: "Redis connection failed: #{e.message}",
        timestamp: Time.current.iso8601
      }
    end
  end

  def check_external_services
    services_status = {}
    
    # Check Customer Service
    services_status[:customer_service] = check_service_health(
      ENV['CUSTOMER_SERVICE_URL'] || 'http://customer-service:3001',
      'customer-service'
    )
    
    # Check Invoice Service
    services_status[:invoice_service] = check_service_health(
      ENV['INVOICE_SERVICE_URL'] || 'http://invoice-service:3002',
      'invoice-service'
    )
    
    # Overall external services status
    all_external_healthy = services_status.values.all? { |s| s[:status] == 'healthy' }
    
    {
      status: all_external_healthy ? 'healthy' : 'degraded',
      services: services_status,
      timestamp: Time.current.iso8601
    }
  end

  def check_service_health(base_url, service_name)
    start_time = Time.current
    
    begin
      uri = URI("#{base_url}/health")
      response = Net::HTTP.get_response(uri)
      
      {
        status: response.code == '200' ? 'healthy' : 'unhealthy',
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        response_code: response.code.to_i,
        message: "#{service_name} health check",
        timestamp: Time.current.iso8601
      }
    rescue => e
      {
        status: 'unhealthy',
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        message: "#{service_name} connection failed: #{e.message}",
        timestamp: Time.current.iso8601
      }
    end
  end

  def check_storage
    begin
      # Check available disk space
      stat = File.statvfs(Rails.root)
      
      total_space = stat.blocks * stat.fragment_size
      free_space = stat.bavail * stat.fragment_size
      used_space = total_space - free_space
      usage_percentage = (used_space.to_f / total_space * 100).round(2)
      
      status = case usage_percentage
               when 0..70 then 'healthy'
               when 70..85 then 'warning'
               else 'critical'
               end
      
      {
        status: status,
        usage_percentage: usage_percentage,
        free_space_gb: (free_space / 1_073_741_824.0).round(2),
        total_space_gb: (total_space / 1_073_741_824.0).round(2),
        message: "Disk usage: #{usage_percentage}%",
        timestamp: Time.current.iso8601
      }
    rescue => e
      {
        status: 'unhealthy',
        message: "Storage check failed: #{e.message}",
        timestamp: Time.current.iso8601
      }
    end
  end
end