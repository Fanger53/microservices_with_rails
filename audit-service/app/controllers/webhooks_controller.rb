class WebhooksController < ApplicationController
  skip_before_action :set_request_metadata, only: [:customer_events, :invoice_events, :system_events]

  # POST /webhooks/customer_events
  # Webhook para recibir eventos del Customer Service
  def customer_events
    process_service_webhook('customer-service', customer_event_params)
  end

  # POST /webhooks/invoice_events
  # Webhook para recibir eventos del Invoice Service
  def invoice_events
    process_service_webhook('invoice-service', invoice_event_params)
  end

  # POST /webhooks/system_events
  # Webhook para eventos del sistema (monitoreo, alertas, etc.)
  def system_events
    process_service_webhook('system', system_event_params)
  end

  private

  def process_service_webhook(service_name, event_data)
    # Validar autenticación del webhook si es necesario
    unless valid_webhook_signature?(service_name)
      return render_error(
        'Invalid webhook signature',
        status: :unauthorized
      )
    end

    begin
      # Crear múltiples audit logs si el evento contiene un array de eventos
      events = event_data.is_a?(Array) ? event_data : [event_data]
      processed_logs = []

      events.each do |event|
        audit_log = create_audit_log_from_webhook(service_name, event)
        processed_logs << audit_log if audit_log
      end

      render_success(
        {
          processed_events: processed_logs.size,
          audit_log_ids: processed_logs.map(&:id)
        },
        message: "#{processed_logs.size} eventos procesados desde #{service_name}"
      )

    rescue => e
      Rails.logger.error({
        event: 'webhook_processing_failed',
        service: service_name,
        error: e.message,
        event_data: event_data
      })

      render_error(
        'Error procesando webhook',
        status: :internal_server_error,
        errors: { service: service_name, error: e.message }
      )
    end
  end

  def create_audit_log_from_webhook(service_name, event_data)
    # Mapear los datos del webhook a nuestro formato de audit log
    audit_attributes = {
      event_id: event_data[:event_id] || SecureRandom.uuid,
      correlation_id: event_data[:correlation_id] || request.headers['X-Correlation-ID'] || SecureRandom.uuid,
      service_name: service_name,
      service_version: event_data[:service_version] || '1.0.0',
      environment: event_data[:environment] || Rails.env,
      action: event_data[:action] || 'webhook_received',
      resource_type: event_data[:resource_type] || 'webhook',
      resource_id: event_data[:resource_id],
      user_id: event_data[:user_id],
      user_type: event_data[:user_type] || 'system',
      user_email: event_data[:user_email],
      ip_address: event_data[:ip_address] || request.remote_ip,
      http_method: 'POST',
      endpoint: request.path,
      request_params: event_data.to_json,
      response_status: 200,
      metadata: event_data[:metadata] || event_data,
      changes: event_data[:changes] || {},
      description: event_data[:description] || "Webhook event from #{service_name}",
      severity: map_severity(event_data[:severity] || event_data[:level]),
      category: map_category(service_name, event_data[:category]),
      status: 'processed',
      sensitive_data: event_data[:sensitive_data] || false,
      pii_data: event_data[:pii_data] || false,
      compliance_tags: event_data[:compliance_tags] || [],
      duration_ms: event_data[:duration_ms],
      error_message: event_data[:error_message],
      error_backtrace: event_data[:error_backtrace],
      error_class: event_data[:error_class],
      occurred_at: parse_webhook_timestamp(event_data[:timestamp] || event_data[:occurred_at])
    }

    AuditLog.create!(audit_attributes)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error({
      event: 'audit_log_creation_failed',
      service: service_name,
      errors: e.record.errors.full_messages,
      event_data: event_data
    })
    nil
  end

  def valid_webhook_signature?(service_name)
    # En un entorno de producción, aquí validarías la firma del webhook
    # usando HMAC, JWT, o el método de autenticación que uses
    
    # Para desarrollo, permitir todos los webhooks
    return true if Rails.env.development?

    # Ejemplo de validación simple con token
    expected_token = ENV["#{service_name.upcase.gsub('-', '_')}_WEBHOOK_TOKEN"]
    provided_token = request.headers['X-Webhook-Token'] || params[:token]

    return true unless expected_token.present?
    
    expected_token == provided_token
  end

  def map_severity(severity)
    case severity&.to_s&.downcase
    when 'debug', 'trace' then 'info'
    when 'info', 'information' then 'info'
    when 'warn', 'warning' then 'warn'
    when 'error', 'err' then 'error'
    when 'fatal', 'critical', 'crit' then 'critical'
    else 'info'
    end
  end

  def map_category(service_name, category)
    case category&.to_s&.downcase
    when 'business', 'domain' then 'business'
    when 'security', 'auth', 'authentication', 'authorization' then 'security'
    when 'system', 'infrastructure', 'ops' then 'system'
    when 'performance', 'perf', 'monitoring' then 'performance'
    when 'compliance', 'audit', 'regulatory' then 'compliance'
    else
      # Mapear por servicio si no hay categoría específica
      case service_name
      when 'customer-service' then 'business'
      when 'invoice-service' then 'business'
      when 'system' then 'system'
      else 'business'
      end
    end
  end

  def parse_webhook_timestamp(timestamp)
    return Time.current unless timestamp.present?

    case timestamp
    when String
      Time.parse(timestamp)
    when Integer
      Time.at(timestamp)
    when Float
      Time.at(timestamp)
    else
      timestamp.respond_to?(:to_time) ? timestamp.to_time : Time.current
    end
  rescue
    Time.current
  end

  def customer_event_params
    params.permit!.except(:controller, :action, :format)
  end

  def invoice_event_params
    params.permit!.except(:controller, :action, :format)
  end

  def system_event_params
    params.permit!.except(:controller, :action, :format)
  end
end