class Api::V1::EventsController < ApplicationController
  # POST /api/v1/events
  # Endpoint principal para recibir eventos de auditoría de otros servicios
  def create
    event_data = event_params
    
    # Validar que el evento tenga los campos mínimos requeridos
    unless valid_event_structure?(event_data)
      return render_error(
        'Invalid event structure',
        status: :bad_request,
        errors: { required_fields: %w[service_name action resource_type occurred_at] }
      )
    end
    
    begin
      # Crear el audit log
      @audit_log = AuditLog.create!(
        event_id: event_data[:event_id] || SecureRandom.uuid,
        correlation_id: @correlation_id,
        service_name: event_data[:service_name],
        service_version: event_data[:service_version] || '1.0.0',
        environment: event_data[:environment] || Rails.env,
        action: event_data[:action],
        resource_type: event_data[:resource_type],
        resource_id: event_data[:resource_id],
        user_id: event_data[:user_id] || current_user_id,
        user_type: event_data[:user_type],
        user_email: event_data[:user_email],
        ip_address: event_data[:ip_address] || request.remote_ip,
        http_method: event_data[:http_method],
        endpoint: event_data[:endpoint],
        request_params: event_data[:request_params]&.to_json,
        response_body: event_data[:response_body]&.to_json,
        response_status: event_data[:response_status],
        metadata: event_data[:metadata] || {},
        changes: event_data[:changes] || {},
        description: event_data[:description],
        severity: event_data[:severity] || 'info',
        category: event_data[:category] || 'business',
        status: 'processed',
        sensitive_data: event_data[:sensitive_data] || false,
        pii_data: event_data[:pii_data] || false,
        compliance_tags: event_data[:compliance_tags] || [],
        duration_ms: event_data[:duration_ms],
        memory_usage_mb: event_data[:memory_usage_mb],
        error_message: event_data[:error_message],
        error_backtrace: event_data[:error_backtrace],
        error_class: event_data[:error_class],
        occurred_at: parse_occurred_at(event_data[:occurred_at])
      )
      
      # Procesamiento asíncrono adicional si es necesario
      if event_data[:process_async]
        AuditEventProcessorJob.perform_later(@audit_log.id)
      end
      
      render_success(
        @audit_log.as_json(only: [:id, :event_id, :correlation_id, :status]),
        status: :created,
        message: 'Evento de auditoría procesado exitosamente'
      )
      
    rescue ActiveRecord::RecordInvalid => e
      render_error(
        'Error al procesar el evento de auditoría',
        status: :unprocessable_entity,
        errors: e.record.errors.full_messages
      )
    rescue => e
      Rails.logger.error({
        event: 'audit_event_processing_failed',
        correlation_id: @correlation_id,
        error: e.message,
        event_data: event_data
      })
      
      render_error(
        'Error interno al procesar el evento',
        status: :internal_server_error
      )
    end
  end

  # POST /api/v1/events/batch
  # Para procesar múltiples eventos de una vez
  def batch
    events = params[:events] || []
    
    if events.empty?
      return render_error(
        'No events provided',
        status: :bad_request
      )
    end
    
    if events.size > 100
      return render_error(
        'Batch size too large (max 100 events)',
        status: :bad_request
      )
    end
    
    processed_events = []
    failed_events = []
    
    events.each_with_index do |event_data, index|
      begin
        unless valid_event_structure?(event_data)
          failed_events << { index: index, error: 'Invalid event structure', event: event_data }
          next
        end
        
        audit_log = AuditLog.create!(build_audit_log_attributes(event_data))
        processed_events << {
          index: index,
          id: audit_log.id,
          event_id: audit_log.event_id,
          status: 'processed'
        }
        
      rescue => e
        failed_events << {
          index: index,
          error: e.message,
          event: event_data
        }
      end
    end
    
    result = {
      processed: processed_events.size,
      failed: failed_events.size,
      total: events.size,
      processed_events: processed_events,
      failed_events: failed_events
    }
    
    status = failed_events.empty? ? :created : :multi_status
    
    render_success(
      result,
      status: status,
      message: "Procesados #{processed_events.size}/#{events.size} eventos"
    )
  end

  private

  def event_params
    params.require(:event).permit(
      :event_id, :service_name, :service_version, :environment,
      :action, :resource_type, :resource_id,
      :user_id, :user_type, :user_email, :ip_address,
      :http_method, :endpoint, :request_params, :response_body, :response_status,
      :description, :severity, :category,
      :sensitive_data, :pii_data, :duration_ms, :memory_usage_mb,
      :error_message, :error_backtrace, :error_class,
      :occurred_at, :process_async,
      compliance_tags: [],
      metadata: {},
      changes: {}
    )
  end

  def valid_event_structure?(event_data)
    required_fields = %w[service_name action resource_type occurred_at]
    required_fields.all? { |field| event_data[field.to_sym].present? || event_data[field].present? }
  end

  def parse_occurred_at(occurred_at)
    return Time.current unless occurred_at.present?
    
    case occurred_at
    when String
      Time.parse(occurred_at)
    when Integer
      Time.at(occurred_at)
    else
      occurred_at
    end
  rescue
    Time.current
  end

  def build_audit_log_attributes(event_data)
    {
      event_id: event_data[:event_id] || SecureRandom.uuid,
      correlation_id: @correlation_id,
      service_name: event_data[:service_name],
      service_version: event_data[:service_version] || '1.0.0',
      environment: event_data[:environment] || Rails.env,
      action: event_data[:action],
      resource_type: event_data[:resource_type],
      resource_id: event_data[:resource_id],
      user_id: event_data[:user_id] || current_user_id,
      user_type: event_data[:user_type],
      user_email: event_data[:user_email],
      ip_address: event_data[:ip_address] || request.remote_ip,
      http_method: event_data[:http_method],
      endpoint: event_data[:endpoint],
      request_params: event_data[:request_params]&.to_json,
      response_body: event_data[:response_body]&.to_json,
      response_status: event_data[:response_status],
      metadata: event_data[:metadata] || {},
      changes: event_data[:changes] || {},
      description: event_data[:description],
      severity: event_data[:severity] || 'info',
      category: event_data[:category] || 'business',
      status: 'processed',
      sensitive_data: event_data[:sensitive_data] || false,
      pii_data: event_data[:pii_data] || false,
      compliance_tags: event_data[:compliance_tags] || [],
      duration_ms: event_data[:duration_ms],
      memory_usage_mb: event_data[:memory_usage_mb],
      error_message: event_data[:error_message],
      error_backtrace: event_data[:error_backtrace],
      error_class: event_data[:error_class],
      occurred_at: parse_occurred_at(event_data[:occurred_at])
    }
  end
end