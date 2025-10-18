class ApplicationController < ActionController::API
  include ActionController::Helpers
  
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def render_success(data, serializer_class = nil, status = :ok)
    if serializer_class
      render json: serializer_class.new(data), status: status
    else
      render json: { data: data }, status: status
    end
  end

  def render_error(errors, status = :unprocessable_entity)
    render json: { 
      errors: Array(errors),
      timestamp: Time.current.iso8601 
    }, status: status
  end

  def not_found(exception)
    render_error("Recurso no encontrado", :not_found)
  end

  def unprocessable_entity(exception)
    render_error(exception.record.errors.full_messages, :unprocessable_entity)
  end

  def bad_request(exception)
    render_error("Parámetros inválidos: #{exception.message}", :bad_request)
  end
end
