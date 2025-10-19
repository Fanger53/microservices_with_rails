class AuthController < ApplicationController
  # Authentication endpoints - no JWT required
  skip_before_action :authenticate_request, only: [:login, :register, :refresh]
  
  def login
    email = params[:email]
    password = params[:password]
    
    if email.blank? || password.blank?
      return error_response('Email and password are required', status: :bad_request)
    end
    
    # For demo purposes, we'll use a simple authentication
    # In production, this should authenticate against a user service or database
    user_data = authenticate_user(email, password)
    
    if user_data
      token_payload = {
        user_id: user_data[:id],
        email: user_data[:email],
        roles: user_data[:roles]
      }
      
      token = JWTService.encode(token_payload)
      refresh_token = JWTService.encode(
        { user_id: user_data[:id], type: 'refresh' },
        7.days.from_now.to_i
      )
      
      # Log authentication event to audit service
      log_auth_event('login', user_data[:id], user_data[:email])
      
      success_response({
        token: token,
        refresh_token: refresh_token,
        user: {
          id: user_data[:id],
          email: user_data[:email],
          roles: user_data[:roles]
        },
        expires_at: Rails.application.config.x.jwt_expiration.from_now.iso8601
      }, message: 'Authentication successful')
    else
      error_response('Invalid email or password', status: :unauthorized)
    end
  end
  
  def register
    email = params[:email]
    password = params[:password]
    name = params[:name]
    
    if email.blank? || password.blank? || name.blank?
      return error_response('Name, email and password are required', status: :bad_request)
    end
    
    # Basic email validation
    unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return error_response('Invalid email format', status: :bad_request)
    end
    
    # For demo purposes, we'll create a mock user
    # In production, this should create a user in a user service or database
    user_data = create_user(name, email, password)
    
    if user_data
      token_payload = {
        user_id: user_data[:id],
        email: user_data[:email],
        roles: user_data[:roles]
      }
      
      token = JWTService.encode(token_payload)
      refresh_token = JWTService.encode(
        { user_id: user_data[:id], type: 'refresh' },
        7.days.from_now.to_i
      )
      
      # Log registration event to audit service
      log_auth_event('register', user_data[:id], user_data[:email])
      
      success_response({
        token: token,
        refresh_token: refresh_token,
        user: {
          id: user_data[:id],
          email: user_data[:email],
          name: user_data[:name],
          roles: user_data[:roles]
        },
        expires_at: Rails.application.config.x.jwt_expiration.from_now.iso8601
      }, message: 'Registration successful', status: :created)
    else
      error_response('Email already exists', status: :conflict)
    end
  end
  
  def refresh
    refresh_token = params[:refresh_token]
    
    if refresh_token.blank?
      return error_response('Refresh token is required', status: :bad_request)
    end
    
    decoded_token = JWTService.decode(refresh_token)
    
    if decoded_token && decoded_token[:type] == 'refresh'
      user_id = decoded_token[:user_id]
      
      # In production, fetch user data from user service
      user_data = get_user_by_id(user_id)
      
      if user_data
        token_payload = {
          user_id: user_data[:id],
          email: user_data[:email],
          roles: user_data[:roles]
        }
        
        new_token = JWTService.encode(token_payload)
        new_refresh_token = JWTService.encode(
          { user_id: user_data[:id], type: 'refresh' },
          7.days.from_now.to_i
        )
        
        success_response({
          token: new_token,
          refresh_token: new_refresh_token,
          user: {
            id: user_data[:id],
            email: user_data[:email],
            roles: user_data[:roles]
          },
          expires_at: Rails.application.config.x.jwt_expiration.from_now.iso8601
        }, message: 'Token refreshed successfully')
      else
        error_response('User not found', status: :not_found)
      end
    else
      error_response('Invalid refresh token', status: :unauthorized)
    end
  end
  
  def logout
    # Log logout event to audit service
    log_auth_event('logout', current_user_id, current_user_email)
    
    success_response(nil, message: 'Logout successful')
  end
  
  def me
    # Return current user information based on JWT
    success_response({
      user: {
        id: current_user_id,
        email: current_user_email,
        roles: current_user_roles
      }
    })
  end
  
  private
  
  def authenticate_user(email, password)
    # Demo users for testing - In production, authenticate against user service
    demo_users = [
      { id: 1, email: 'admin@example.com', password: 'admin123', name: 'Admin User', roles: ['admin'] },
      { id: 2, email: 'user@example.com', password: 'user123', name: 'Regular User', roles: ['user'] },
      { id: 3, email: 'invoice@example.com', password: 'invoice123', name: 'Invoice User', roles: ['user', 'invoice_manager'] }
    ]
    
    user = demo_users.find { |u| u[:email] == email && u[:password] == password }
    user&.except(:password)
  end
  
  def create_user(name, email, password)
    # Demo user creation - In production, create in user service
    # Check if email already exists
    demo_users = [
      { email: 'admin@example.com' },
      { email: 'user@example.com' },
      { email: 'invoice@example.com' }
    ]
    
    return nil if demo_users.any? { |u| u[:email] == email }
    
    # Create new user (mock)
    {
      id: rand(1000..9999),
      name: name,
      email: email,
      roles: ['user']
    }
  end
  
  def get_user_by_id(user_id)
    # Demo user lookup - In production, fetch from user service
    demo_users = [
      { id: 1, email: 'admin@example.com', name: 'Admin User', roles: ['admin'] },
      { id: 2, email: 'user@example.com', name: 'Regular User', roles: ['user'] },
      { id: 3, email: 'invoice@example.com', name: 'Invoice User', roles: ['user', 'invoice_manager'] }
    ]
    
    demo_users.find { |u| u[:id] == user_id }
  end
  
  def log_auth_event(action, user_id, email)
    begin
      # Send audit log to audit service
      audit_data = {
        event_type: 'authentication',
        action: action,
        user_id: user_id,
        user_email: email,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        timestamp: Time.current.iso8601
      }
      
      # Use circuit breaker for audit service call
      circuit_breaker = Rails.application.config.x.circuit_breakers[:audit_service]
      
      circuit_breaker.call do
        conn = Faraday.new(url: Rails.application.config.x.services.audit_service.base_url) do |f|
          f.request :json
          f.response :json
          f.adapter :net_http
          f.options.timeout = 5
        end
        
        conn.post('/api/audit_logs', { audit_log: audit_data })
      end
    rescue => e
      Rails.logger.warn "Failed to log auth event to audit service: #{e.message}"
      # Don't fail authentication if audit logging fails
    end
  end
end