class ProxyController < ApplicationController
  # Main proxy controller to route requests to backend services
  
  def customer_service
    proxy_request_to_service(:customer_service, params[:path])
  end
  
  def invoice_service
    proxy_request_to_service(:invoice_service, params[:path])
  end
  
  def audit_service
    proxy_request_to_service(:audit_service, params[:path])
  end
  
  private
  
  def proxy_request_to_service(service_name, path)
    service_config = Rails.application.config.x.services.send(service_name)
    circuit_breaker = Rails.application.config.x.circuit_breakers[service_name]
    
    # Build the target URL
    target_url = "#{service_config.base_url}/#{path}"
    target_url += "?#{request.query_string}" unless request.query_string.blank?
    
    begin
      # Use circuit breaker for resilience
      response = circuit_breaker.call do
        make_service_request(target_url)
      end
      
      # Forward the response
      forward_response(response)
      
    rescue CircuitBreaker::CircuitBreakerError => e
      Rails.logger.warn "Circuit breaker open for #{service_name}: #{e.message}"
      render json: {
        error: 'Service temporarily unavailable',
        service: service_name.to_s,
        message: 'The service is experiencing issues. Please try again later.',
        request_id: request.uuid
      }, status: :service_unavailable
      
    rescue Faraday::TimeoutError => e
      Rails.logger.warn "Timeout calling #{service_name}: #{e.message}"
      render json: {
        error: 'Service timeout',
        service: service_name.to_s,
        message: 'The service request timed out.',
        request_id: request.uuid
      }, status: :gateway_timeout
      
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "Connection failed to #{service_name}: #{e.message}"
      render json: {
        error: 'Service unavailable',
        service: service_name.to_s,
        message: 'Unable to connect to the service.',
        request_id: request.uuid
      }, status: :bad_gateway
      
    rescue => e
      Rails.logger.error "Unexpected error proxying to #{service_name}: #{e.message}"
      render json: {
        error: 'Proxy error',
        service: service_name.to_s,
        message: 'An error occurred while processing the request.',
        request_id: request.uuid
      }, status: :internal_server_error
    end
  end
  
  def make_service_request(target_url)
    # Create Faraday connection with timeout settings
    conn = Faraday.new do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :net_http
      f.options.timeout = 30
      f.options.open_timeout = 5
    end
    
    # Prepare headers to forward
    headers = build_forwarded_headers
    
    # Make the request based on HTTP method
    case request.method.upcase
    when 'GET'
      conn.get(target_url, nil, headers)
    when 'POST'
      conn.post(target_url, request_body, headers)
    when 'PUT'
      conn.put(target_url, request_body, headers)
    when 'PATCH'
      conn.patch(target_url, request_body, headers)
    when 'DELETE'
      conn.delete(target_url, nil, headers)
    else
      raise "Unsupported HTTP method: #{request.method}"
    end
  end
  
  def build_forwarded_headers
    headers = {}
    
    # Forward Content-Type if present
    headers['Content-Type'] = request.content_type if request.content_type
    
    # Forward Accept header
    headers['Accept'] = request.headers['Accept'] if request.headers['Accept']
    
    # Add user information from JWT for backend services
    if @current_user_data
      headers['X-User-ID'] = @current_user_data[:user_id].to_s
      headers['X-User-Email'] = @current_user_data[:email]
      headers['X-User-Roles'] = @current_user_data[:roles].join(',') if @current_user_data[:roles]
    end
    
    # Add tracing headers
    headers['X-Request-ID'] = request.uuid
    headers['X-Forwarded-For'] = request.remote_ip
    headers['X-Forwarded-Proto'] = request.protocol.gsub('://', '')
    headers['X-Forwarded-Host'] = request.host
    
    # Add API Gateway identification
    headers['X-Gateway'] = 'api-gateway'
    headers['X-Gateway-Version'] = '1.0.0'
    
    headers
  end
  
  def request_body
    return nil if request.get? || request.delete?
    
    # Get raw body for non-GET/DELETE requests
    request.body.rewind if request.body.respond_to?(:rewind)
    body = request.body.read
    
    # Try to parse as JSON to validate
    if request.content_type&.include?('application/json') && !body.blank?
      begin
        JSON.parse(body)
        body
      rescue JSON::ParserError => e
        Rails.logger.warn "Invalid JSON in request body: #{e.message}"
        '{}'
      end
    else
      body
    end
  end
  
  def forward_response(response)
    # Set appropriate status code
    status_code = response.status
    
    # Forward response headers (selectively)
    forwarded_headers = {}
    if response.headers['Content-Type']
      forwarded_headers['Content-Type'] = response.headers['Content-Type']
    end
    if response.headers['Cache-Control']
      forwarded_headers['Cache-Control'] = response.headers['Cache-Control']
    end
    
    # Add our own headers
    forwarded_headers['X-Proxy'] = 'api-gateway'
    forwarded_headers['X-Request-ID'] = request.uuid
    forwarded_headers['X-Response-Time'] = (Time.current.to_f * 1000).round(2).to_s
    
    # Set headers
    forwarded_headers.each do |key, value|
      response.headers[key] = value
    end
    
    # Return the response body
    begin
      if response.body.is_a?(Hash) || response.body.is_a?(Array)
        # JSON response
        render json: response.body, status: status_code
      elsif response.body.is_a?(String)
        # Try to parse as JSON, fallback to plain text
        begin
          parsed_body = JSON.parse(response.body)
          render json: parsed_body, status: status_code
        rescue JSON::ParserError
          render plain: response.body, status: status_code
        end
      else
        # Empty or unknown response
        head status_code
      end
    rescue => e
      Rails.logger.error "Error forwarding response: #{e.message}"
      render json: {
        error: 'Response forwarding error',
        message: 'Error processing service response',
        request_id: request.uuid
      }, status: :internal_server_error
    end
  end
end