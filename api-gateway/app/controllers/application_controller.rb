class ApplicationController < ActionController::API
  include ActionController::Helpers
  
  # JWT Authentication
  before_action :authenticate_request, except: [:health_check, :auth]
  
  # Error handling
  rescue_from StandardError, with: :handle_internal_error
  rescue_from CircuitBreaker::CircuitBreakerError, with: :handle_service_unavailable
  rescue_from Faraday::TimeoutError, with: :handle_timeout_error
  rescue_from Faraday::ConnectionFailed, with: :handle_connection_error
  
  # CORS headers
  before_action :set_cors_headers
  
  protected
  
  def authenticate_request
    token = extract_token_from_header
    
    if token
      @current_user_data = JWTService.decode(token)
      unless @current_user_data
        render json: { error: 'Invalid or expired token' }, status: :unauthorized
        return
      end
    else
      render json: { error: 'Authorization token required' }, status: :unauthorized
      return
    end
  end
  
  def current_user_id
    @current_user_data&.dig(:user_id)
  end
  
  def current_user_email
    @current_user_data&.dig(:email)
  end
  
  def current_user_roles
    @current_user_data&.dig(:roles) || []
  end
  
  private
  
  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil unless auth_header
    
    # Expected format: "Bearer <token>"
    token = auth_header.split(' ').last
    token if auth_header.start_with?('Bearer ')
  end
  
  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, X-API-Key, X-Requested-With'
    response.headers['Access-Control-Expose-Headers'] = 'X-Request-ID, X-Response-Time'
    
    # Add request ID for tracing
    response.headers['X-Request-ID'] = request.uuid
  end
  
  # Error handlers
  def handle_internal_error(exception)
    Rails.logger.error "Internal error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render json: {
      error: 'Internal server error',
      message: 'An unexpected error occurred',
      request_id: request.uuid
    }, status: :internal_server_error
  end
  
  def handle_service_unavailable(exception)
    Rails.logger.warn "Service unavailable: #{exception.message}"
    
    render json: {
      error: 'Service unavailable',
      message: 'The requested service is temporarily unavailable',
      request_id: request.uuid
    }, status: :service_unavailable
  end
  
  def handle_timeout_error(exception)
    Rails.logger.warn "Service timeout: #{exception.message}"
    
    render json: {
      error: 'Service timeout',
      message: 'The service request timed out',
      request_id: request.uuid
    }, status: :gateway_timeout
  end
  
  def handle_connection_error(exception)
    Rails.logger.error "Connection error: #{exception.message}"
    
    render json: {
      error: 'Service connection error',
      message: 'Unable to connect to the requested service',
      request_id: request.uuid
    }, status: :bad_gateway
  end
  
  # Response helpers
  def success_response(data, message: nil, status: :ok)
    response_body = {
      success: true,
      data: data,
      request_id: request.uuid
    }
    response_body[:message] = message if message
    
    render json: response_body, status: status
  end
  
  def error_response(message, errors: nil, status: :bad_request)
    response_body = {
      success: false,
      error: message,
      request_id: request.uuid
    }
    response_body[:errors] = errors if errors
    
    render json: response_body, status: status
  end
end