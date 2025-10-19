class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # Headers para identificar requests entre servicios
  SERVICE_HEADERS = %w[
    X-Service-Name
    X-Service-Version 
    X-Correlation-ID
    X-Request-ID
    X-User-ID
    X-User-Type
  ].freeze

  # Filtros globales
  before_action :set_correlation_id
  before_action :set_request_metadata
  before_action :log_request_start
  after_action :log_request_end

  # Manejo de errores
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  private

  def set_correlation_id
    @correlation_id = request.headers['X-Correlation-ID'] || SecureRandom.uuid
    response.headers['X-Correlation-ID'] = @correlation_id
  end

  def set_request_metadata
    @request_metadata = {
      correlation_id: @correlation_id,
      request_id: request.uuid,
      service_name: request.headers['X-Service-Name'] || 'unknown',
      service_version: request.headers['X-Service-Version'] || '1.0.0',
      user_id: request.headers['X-User-ID'],
      user_type: request.headers['X-User-Type'] || 'anonymous',
      ip_address: request.remote_ip,
      user_agent: request.headers['User-Agent'],
      endpoint: "#{request.method} #{request.path}",
      request_started_at: Time.current
    }
  end

  def log_request_start
    Rails.logger.info({
      event: 'request_started',
      **@request_metadata,
      params: filtered_params
    })
  end

  def log_request_end
    duration_ms = ((Time.current - @request_metadata[:request_started_at]) * 1000).round(2)
    
    Rails.logger.info({
      event: 'request_completed',
      correlation_id: @correlation_id,
      duration_ms: duration_ms,
      response_status: response.status,
      response_size: response.body&.bytesize || 0
    })

    # Crear log de auditoría de manera asíncrona
    AuditLoggerJob.perform_later(
      @request_metadata.merge(
        duration_ms: duration_ms,
        response_status: response.status,
        response_size: response.body&.bytesize || 0,
        occurred_at: @request_metadata[:request_started_at]
      )
    )
  end

  def current_user_id
    @request_metadata[:user_id]
  end

  def current_service
    @request_metadata[:service_name]
  end

  def filtered_params
    # Filtrar parámetros sensibles para logs
    params.except(:password, :token, :secret, :key).to_unsafe_h
  end

  def render_success(data, status: :ok, message: nil)
    response_data = {
      success: true,
      data: data,
      meta: {
        correlation_id: @correlation_id,
        timestamp: Time.current.iso8601,
        service: 'audit-service'
      }
    }
    response_data[:message] = message if message.present?

    render json: response_data, status: status
  end

  def render_error(message, status: :unprocessable_entity, errors: nil)
    response_data = {
      success: false,
      error: {
        message: message,
        details: errors
      },
      meta: {
        correlation_id: @correlation_id,
        timestamp: Time.current.iso8601,
        service: 'audit-service'
      }
    }

    render json: response_data, status: status
  end

  def paginate_collection(collection, per_page: 25)
    page = [params[:page].to_i, 1].max
    per_page = [[params[:per_page].to_i, per_page].max, 100].min

    paginated = collection.page(page).per(per_page)
    
    {
      data: paginated,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_pages: paginated.total_pages,
        total_count: paginated.total_count,
        has_next_page: page < paginated.total_pages,
        has_prev_page: page > 1
      }
    }
  end

  # Error handlers
  def handle_standard_error(exception)
    Rails.logger.error({
      event: 'error_occurred',
      correlation_id: @correlation_id,
      error_class: exception.class.name,
      error_message: exception.message,
      error_backtrace: exception.backtrace&.first(10)
    })

    render_error(
      'Ha ocurrido un error interno del servidor',
      status: :internal_server_error,
      errors: Rails.env.development? ? { 
        exception: exception.message,
        backtrace: exception.backtrace&.first(5) 
      } : nil
    )
  end

  def handle_not_found(exception)
    render_error(
      'El recurso solicitado no fue encontrado',
      status: :not_found,
      errors: { resource: exception.message }
    )
  end

  def handle_parameter_missing(exception)
    render_error(
      'Faltan parámetros requeridos',
      status: :bad_request,
      errors: { parameter: exception.param }
    )
  end

  def handle_unauthorized(exception)
    render_error(
      'No tienes permisos para realizar esta acción',
      status: :forbidden,
      errors: { authorization: exception.message }
    )
  end
end