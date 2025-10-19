class DashboardController < ApplicationController
  # Aggregated endpoints that combine data from multiple services
  
  def overview
    # Get overview data from all services
    begin
      overview_data = {
        customers: get_customer_summary,
        invoices: get_invoice_summary,
        recent_activity: get_recent_activity,
        system_health: get_system_health,
        timestamp: Time.current.iso8601
      }
      
      success_response(overview_data, message: 'Dashboard overview retrieved successfully')
      
    rescue => e
      Rails.logger.error "Error fetching dashboard overview: #{e.message}"
      error_response('Unable to fetch dashboard data', status: :service_unavailable)
    end
  end
  
  def customer_invoices
    # Get customer data along with their invoices
    customer_id = params[:customer_id]
    
    if customer_id.blank?
      return error_response('Customer ID is required', status: :bad_request)
    end
    
    begin
      customer_data = get_customer_details(customer_id)
      return error_response('Customer not found', status: :not_found) unless customer_data
      
      invoice_data = get_customer_invoices(customer_id)
      
      combined_data = {
        customer: customer_data,
        invoices: invoice_data[:invoices] || [],
        invoice_summary: {
          total_count: invoice_data[:total_count] || 0,
          total_amount: invoice_data[:total_amount] || 0,
          pending_count: invoice_data[:pending_count] || 0,
          paid_count: invoice_data[:paid_count] || 0
        }
      }
      
      success_response(combined_data, message: 'Customer invoices retrieved successfully')
      
    rescue => e
      Rails.logger.error "Error fetching customer invoices: #{e.message}"
      error_response('Unable to fetch customer invoice data', status: :service_unavailable)
    end
  end
  
  def invoice_details
    # Get invoice with customer details and audit logs
    invoice_id = params[:invoice_id]
    
    if invoice_id.blank?
      return error_response('Invoice ID is required', status: :bad_request)
    end
    
    begin
      invoice_data = get_invoice_details(invoice_id)
      return error_response('Invoice not found', status: :not_found) unless invoice_data
      
      customer_data = get_customer_details(invoice_data[:customer_id]) if invoice_data[:customer_id]
      audit_logs = get_invoice_audit_logs(invoice_id)
      
      combined_data = {
        invoice: invoice_data,
        customer: customer_data,
        audit_logs: audit_logs || [],
        timeline: build_invoice_timeline(invoice_data, audit_logs)
      }
      
      success_response(combined_data, message: 'Invoice details retrieved successfully')
      
    rescue => e
      Rails.logger.error "Error fetching invoice details: #{e.message}"
      error_response('Unable to fetch invoice details', status: :service_unavailable)
    end
  end
  
  def analytics
    # Get analytics data combining information from all services
    date_range = params[:date_range] || '30'
    
    begin
      analytics_data = {
        date_range: "#{date_range} days",
        customers: get_customer_analytics(date_range),
        invoices: get_invoice_analytics(date_range),
        activity: get_activity_analytics(date_range),
        generated_at: Time.current.iso8601
      }
      
      success_response(analytics_data, message: 'Analytics data retrieved successfully')
      
    rescue => e
      Rails.logger.error "Error fetching analytics: #{e.message}"
      error_response('Unable to fetch analytics data', status: :service_unavailable)
    end
  end
  
  private
  
  def get_customer_summary
    circuit_breaker = Rails.application.config.x.circuit_breakers[:customer_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:customer_service)
      response = conn.get('/api/customers/summary', nil, service_headers)
      
      if response.success?
        response.body
      else
        { error: 'Unable to fetch customer summary', total_count: 0 }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch customer summary: #{e.message}"
    { error: 'Service unavailable', total_count: 0 }
  end
  
  def get_invoice_summary
    circuit_breaker = Rails.application.config.x.circuit_breakers[:invoice_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:invoice_service)
      response = conn.get('/api/invoices/summary', nil, service_headers)
      
      if response.success?
        response.body
      else
        { error: 'Unable to fetch invoice summary', total_count: 0 }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch invoice summary: #{e.message}"
    { error: 'Service unavailable', total_count: 0 }
  end
  
  def get_recent_activity
    circuit_breaker = Rails.application.config.x.circuit_breakers[:audit_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:audit_service)
      response = conn.get('/api/audit_logs/recent', { limit: 10 }, service_headers)
      
      if response.success?
        response.body
      else
        { activities: [], error: 'Unable to fetch recent activity' }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch recent activity: #{e.message}"
    { activities: [], error: 'Service unavailable' }
  end
  
  def get_system_health
    {
      customer_service: check_service_health(:customer_service),
      invoice_service: check_service_health(:invoice_service),
      audit_service: check_service_health(:audit_service)
    }
  end
  
  def get_customer_details(customer_id)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:customer_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:customer_service)
      response = conn.get("/api/customers/#{customer_id}", nil, service_headers)
      
      response.success? ? response.body : nil
    end
  rescue => e
    Rails.logger.warn "Failed to fetch customer details: #{e.message}"
    nil
  end
  
  def get_customer_invoices(customer_id)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:invoice_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:invoice_service)
      response = conn.get('/api/invoices', { customer_id: customer_id }, service_headers)
      
      if response.success?
        response.body
      else
        { invoices: [], total_count: 0 }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch customer invoices: #{e.message}"
    { invoices: [], total_count: 0 }
  end
  
  def get_invoice_details(invoice_id)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:invoice_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:invoice_service)
      response = conn.get("/api/invoices/#{invoice_id}", nil, service_headers)
      
      response.success? ? response.body : nil
    end
  rescue => e
    Rails.logger.warn "Failed to fetch invoice details: #{e.message}"
    nil
  end
  
  def get_invoice_audit_logs(invoice_id)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:audit_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:audit_service)
      response = conn.get('/api/audit_logs', { 
        resource_type: 'Invoice',
        resource_id: invoice_id
      }, service_headers)
      
      if response.success?
        response.body&.dig(:audit_logs) || []
      else
        []
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch invoice audit logs: #{e.message}"
    []
  end
  
  def get_customer_analytics(date_range)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:customer_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:customer_service)
      response = conn.get('/api/customers/analytics', { days: date_range }, service_headers)
      
      if response.success?
        response.body
      else
        { error: 'Unable to fetch customer analytics' }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch customer analytics: #{e.message}"
    { error: 'Service unavailable' }
  end
  
  def get_invoice_analytics(date_range)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:invoice_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:invoice_service)
      response = conn.get('/api/invoices/analytics', { days: date_range }, service_headers)
      
      if response.success?
        response.body
      else
        { error: 'Unable to fetch invoice analytics' }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch invoice analytics: #{e.message}"
    { error: 'Service unavailable' }
  end
  
  def get_activity_analytics(date_range)
    circuit_breaker = Rails.application.config.x.circuit_breakers[:audit_service]
    
    circuit_breaker.call do
      conn = create_service_connection(:audit_service)
      response = conn.get('/api/audit_logs/analytics', { days: date_range }, service_headers)
      
      if response.success?
        response.body
      else
        { error: 'Unable to fetch activity analytics' }
      end
    end
  rescue => e
    Rails.logger.warn "Failed to fetch activity analytics: #{e.message}"
    { error: 'Service unavailable' }
  end
  
  def build_invoice_timeline(invoice_data, audit_logs)
    timeline = []
    
    # Add creation event
    if invoice_data[:created_at]
      timeline << {
        event: 'created',
        timestamp: invoice_data[:created_at],
        description: 'Invoice created',
        user: 'System'
      }
    end
    
    # Add audit log events
    audit_logs.each do |log|
      timeline << {
        event: log[:action] || 'updated',
        timestamp: log[:created_at],
        description: log[:description] || "Invoice #{log[:action]}",
        user: log[:user_email] || 'System'
      }
    end
    
    # Sort by timestamp
    timeline.sort_by { |event| Time.parse(event[:timestamp]) rescue Time.current }
  end
  
  def check_service_health(service_name)
    service_config = Rails.application.config.x.services.send(service_name)
    
    begin
      conn = Faraday.new(url: service_config.base_url) do |f|
        f.adapter :net_http
        f.options.timeout = 5
        f.options.open_timeout = 2
      end
      
      response = conn.get('/health')
      {
        status: response.success? ? 'healthy' : 'unhealthy',
        response_time: 'fast'
      }
    rescue => e
      {
        status: 'unavailable',
        error: e.message
      }
    end
  end
  
  def create_service_connection(service_name)
    service_config = Rails.application.config.x.services.send(service_name)
    
    Faraday.new(url: service_config.base_url) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :net_http
      f.options.timeout = 30
      f.options.open_timeout = 5
    end
  end
  
  def service_headers
    headers = {
      'Content-Type' => 'application/json',
      'X-Request-ID' => request.uuid,
      'X-Gateway' => 'api-gateway'
    }
    
    # Add user context if authenticated
    if @current_user_data
      headers['X-User-ID'] = @current_user_data[:user_id].to_s
      headers['X-User-Email'] = @current_user_data[:email]
      headers['X-User-Roles'] = @current_user_data[:roles].join(',') if @current_user_data[:roles]
    end
    
    headers
  end
end