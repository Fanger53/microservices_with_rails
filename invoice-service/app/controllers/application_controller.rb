class ApplicationController < ActionController::API
  include ActionController::Helpers
  
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from StandardError, with: :internal_server_error

  private

  def render_success(data, serializer_class = nil, status = :ok, meta = {})
    response_data = if serializer_class
      serializer_class.new(data, meta: meta)
    else
      { data: data }
    end
    
    response_data[:meta] = meta if meta.any?
    render json: response_data, status: status
  end

  def render_error(errors, status = :unprocessable_entity, details = {})
    render json: { 
      errors: Array(errors),
      timestamp: Time.current.iso8601,
      details: details
    }, status: status
  end

  def not_found(exception)
    render_error("Recurso no encontrado: #{exception.message}", :not_found)
  end

  def unprocessable_entity(exception)
    render_error(exception.record.errors.full_messages, :unprocessable_entity)
  end

  def bad_request(exception)
    render_error("Parámetros inválidos: #{exception.message}", :bad_request)
  end

  def internal_server_error(exception)
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render_error(
      "Error interno del servidor", 
      :internal_server_error,
      { error_id: SecureRandom.uuid }
    )
  end

  # Método para paginación
  def paginate_collection(collection, page: 1, per_page: 20)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min
    
    offset = (page - 1) * per_page
    
    {
      collection: collection.limit(per_page).offset(offset),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: collection.count,
        total_pages: (collection.count.to_f / per_page).ceil
      }
    }
  end
end