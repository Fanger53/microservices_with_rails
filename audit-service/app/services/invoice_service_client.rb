class InvoiceServiceClient
  include CircuitBreaker

  BASE_URL = ENV['INVOICE_SERVICE_URL'] || 'http://invoice-service:3002'
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

  def find_invoice(invoice_id)
    circuit do
      cache_key = "invoice:#{invoice_id}"
      
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        response = @client.get("/api/v1/invoices/#{invoice_id}") do |req|
          req.headers['X-Service-Name'] = 'audit-service'
          req.headers['X-Service-Version'] = '1.0.0'
          req.headers['Accept'] = 'application/json'
        end

        if response.success?
          response.body['data']
        else
          Rails.logger.error({
            event: 'invoice_service_error',
            invoice_id: invoice_id,
            status: response.status,
            body: response.body
          })
          nil
        end
      end
    end
  rescue CircuitBreaker::OpenError
    Rails.logger.error({
      event: 'invoice_service_circuit_open',
      invoice_id: invoice_id
    })
    nil
  rescue => e
    Rails.logger.error({
      event: 'invoice_service_request_failed',
      invoice_id: invoice_id,
      error: e.message
    })
    nil
  end

  def get_invoice_statistics(start_date = 30.days.ago, end_date = Time.current)
    circuit do
      cache_key = "invoice_stats:#{start_date.to_date}:#{end_date.to_date}"
      
      Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
        response = @client.get('/api/v1/invoices/summary') do |req|
          req.params['start_date'] = start_date.iso8601
          req.params['end_date'] = end_date.iso8601
          req.headers['X-Service-Name'] = 'audit-service'
        end

        if response.success?
          response.body['data']
        else
          Rails.logger.error({
            event: 'invoice_statistics_request_failed',
            status: response.status
          })
          { total: 0, amount: 0, error: 'Service unavailable' }
        end
      end
    end
  rescue => e
    Rails.logger.error({
      event: 'invoice_statistics_error',
      error: e.message
    })
    { total: 0, amount: 0, error: e.message }
  end

  def get_customer_invoices(customer_id, limit = 10)
    circuit do
      response = @client.get('/api/v1/invoices') do |req|
        req.params['customer_id'] = customer_id
        req.params['limit'] = limit
        req.headers['X-Service-Name'] = 'audit-service'
      end

      if response.success?
        response.body['data'] || []
      else
        Rails.logger.error({
          event: 'customer_invoices_request_failed',
          customer_id: customer_id,
          status: response.status
        })
        []
      end
    end
  rescue => e
    Rails.logger.error({
      event: 'customer_invoices_error',
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

  def get_invoice_activity_for_audit(invoice_id)
    circuit do
      response = @client.get("/api/v1/invoices/#{invoice_id}/audit") do |req|
        req.headers['X-Service-Name'] = 'audit-service'
      end

      if response.success?
        response.body['data']
      else
        Rails.logger.warn({
          event: 'invoice_audit_data_unavailable',
          invoice_id: invoice_id,
          status: response.status
        })
        nil
      end
    end
  rescue => e
    Rails.logger.error({
      event: 'invoice_audit_request_error',
      invoice_id: invoice_id,
      error: e.message
    })
    nil
  end

  def get_tax_calculations_history(invoice_id)
    circuit do
      response = @client.get("/api/v1/invoices/#{invoice_id}/tax_history") do |req|
        req.headers['X-Service-Name'] = 'audit-service'
      end

      if response.success?
        response.body['data'] || []
      else
        []
      end
    end
  rescue => e
    Rails.logger.error({
      event: 'tax_history_request_error',
      invoice_id: invoice_id,
      error: e.message
    })
    []
  end

  private

  def circuit_key
    'invoice_service'
  end
end