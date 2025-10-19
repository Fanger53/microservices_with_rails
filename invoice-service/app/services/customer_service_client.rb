class CustomerServiceClient
  include CircuitBreaker
  
  BASE_URL = Rails.application.config.customer_service_url
  TIMEOUT = 10.seconds
  
  # Rails 8 - Circuit breaker para resiliencia
  circuit_breaker :customer_service_breaker, {
    failure_threshold: 5,
    timeout: 30.seconds,
    expected_exception: Faraday::Error
  }

  def self.find_customer(customer_id)
    with_circuit_breaker(:customer_service_breaker) do
      response = connection.get("/api/v1/customers/#{customer_id}")
      
      if response.success?
        JSON.parse(response.body)
      else
        Rails.logger.error "Customer Service error: #{response.status} - #{response.body}"
        nil
      end
    end
  rescue CircuitBreaker::OpenError
    Rails.logger.error "Customer Service circuit breaker is open"
    nil
  rescue => e
    Rails.logger.error "Customer Service client error: #{e.message}"
    nil
  end

  def self.validate_customer_for_invoicing(customer_id)
    with_circuit_breaker(:customer_service_breaker) do
      response = connection.get("/api/v1/customers/#{customer_id}/validate_invoice_capability")
      
      if response.success?
        JSON.parse(response.body)
      else
        { can_invoice: false, validation_errors: ['Customer service unavailable'] }
      end
    end
  rescue CircuitBreaker::OpenError
    { can_invoice: false, validation_errors: ['Customer service circuit breaker open'] }
  rescue => e
    Rails.logger.error "Customer validation error: #{e.message}"
    { can_invoice: false, validation_errors: ['Customer validation failed'] }
  end

  def self.search_customers(query, limit: 10)
    with_circuit_breaker(:customer_service_breaker) do
      response = connection.get("/api/v1/customers/search", { 
        q: query, 
        limit: limit 
      })
      
      if response.success?
        JSON.parse(response.body)
      else
        []
      end
    end
  rescue => e
    Rails.logger.error "Customer search error: #{e.message}"
    []
  end

  # Método para invalidar cache cuando se actualiza un cliente
  def self.invalidate_customer_cache(customer_id)
    Rails.cache.delete("customer_#{customer_id}")
  end

  # Método con cache para consultas frecuentes
  def self.find_customer_cached(customer_id, expires_in: 5.minutes)
    Rails.cache.fetch("customer_#{customer_id}", expires_in: expires_in) do
      find_customer(customer_id)
    end
  end

  private

  def self.connection
    @connection ||= Faraday.new(
      url: BASE_URL,
      request: { timeout: TIMEOUT }
    ) do |conn|
      conn.request :json
      conn.response :json
      conn.response :logger, Rails.logger, { headers: true, bodies: true } if Rails.env.development?
      
      # Rails 8 - Retry automático con backoff exponencial
      conn.request :retry, {
        max: 3,
        interval: 0.5,
        backoff_factor: 2,
        exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
      }
      
      conn.adapter Faraday.default_adapter
    end
  end

  # Método para health check del Customer Service
  def self.healthy?
    response = connection.get('/health')
    response.success? && JSON.parse(response.body)['status'] == 'ok'
  rescue
    false
  end

  # Método para obtener métricas del Customer Service
  def self.metrics
    {
      base_url: BASE_URL,
      circuit_breaker_status: circuit_breaker_status(:customer_service_breaker),
      last_request_at: @last_request_at,
      total_requests: @total_requests || 0,
      failed_requests: @failed_requests || 0
    }
  end

  private

  def self.circuit_breaker_status(breaker_name)
    # Implementar lógica para obtener estado del circuit breaker
    'closed' # Por ahora retornamos closed
  end
end