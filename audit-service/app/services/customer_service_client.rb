class CustomerServiceClient
  include CircuitBreaker

  BASE_URL = ENV['CUSTOMER_SERVICE_URL'] || 'http://customer-service:3001'
  TIMEOUT = 5.seconds
  CACHE_TTL = 5.minutes

  def initialize
    @client = Faraday.new(url: BASE_URL) do |faraday|
      faraday.request :json
      faraday.request :retry, max: 3, interval: 0.5
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = TIMEOUT
    end

    # Configurar circuit breaker
    circuit_handler.failure_threshold = 5
    circuit_handler.recovery_timeout = 30.seconds
  end

  def find_customer(customer_id)
    circuit do
      cache_key = "customer:#{customer_id}"
      
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        response = @client.get("/api/v1/customers/#{customer_id}") do |req|
          req.headers['X-Service-Name'] = 'audit-service'
          req.headers['X-Service-Version'] = '1.0.0'
          req.headers['Accept'] = 'application/json'
        end

        if response.success?
          response.body['data']
        else
          Rails.logger.error({
            event: 'customer_service_error',
            customer_id: customer_id,
            status: response.status,
            body: response.body
          })
          nil
        end
      end
    end
  rescue CircuitBreaker::OpenError
    Rails.logger.error({
      event: 'customer_service_circuit_open',
      customer_id: customer_id
    })
    nil
  rescue => e
    Rails.logger.error({
      event: 'customer_service_request_failed',
      customer_id: customer_id,
      error: e.message
    })
    nil
  end

  def get_customer_activity(customer_id, start_date = 30.days.ago, end_date = Time.current)
    circuit do
      response = @client.get("/api/v1/customers/#{customer_id}/activity") do |req|
        req.params['start_date'] = start_date.iso8601
        req.params['end_date'] = end_date.iso8601
        req.headers['X-Service-Name'] = 'audit-service'
        req.headers['X-Service-Version'] = '1.0.0'
      end

      if response.success?
        response.body['data']
      else
        Rails.logger.error({
          event: 'customer_activity_request_failed',
          customer_id: customer_id,
          status: response.status
        })
        []
      end
    end
  rescue => e
    Rails.logger.error({
      event: 'customer_activity_error',
      customer_id: customer_id,
      error: e.message
    })
    []
  end

  def health_check
    circuit do
      response = @client.get('/health') do |req|
        req.headers['X-Service-Name'] = 'audit-service'
      end

      {
        status: response.success? ? 'healthy' : 'unhealthy',
        response_time: response.env.request.tap(&:finish).response_time,
        details: response.body
      }
    end
  rescue => e
    {
      status: 'unhealthy',
      error: e.message
    }
  end

  def get_customers_summary
    circuit do
      cache_key = 'customers:summary'
      
      Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        response = @client.get('/api/v1/customers/summary') do |req|
          req.headers['X-Service-Name'] = 'audit-service'
        end

        if response.success?
          response.body['data']
        else
          { total: 0, active: 0, error: 'Service unavailable' }
        end
      end
    end
  rescue => e
    { total: 0, active: 0, error: e.message }
  end

  private

  def circuit_key
    'customer_service'
  end
end