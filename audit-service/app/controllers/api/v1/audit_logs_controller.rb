class Api::V1::AuditLogsController < ApplicationController
  before_action :set_audit_log, only: [:show]

  # GET /api/v1/audit_logs
  def index
    @audit_logs = AuditLog.all
    
    # Aplicar filtros
    @audit_logs = filter_by_service(@audit_logs)
    @audit_logs = filter_by_action(@audit_logs)
    @audit_logs = filter_by_severity(@audit_logs)
    @audit_logs = filter_by_category(@audit_logs)
    @audit_logs = filter_by_user(@audit_logs)
    @audit_logs = filter_by_date_range(@audit_logs)
    @audit_logs = filter_by_resource(@audit_logs)
    
    # Ordenar
    @audit_logs = @audit_logs.recent
    
    # Paginar
    result = paginate_collection(@audit_logs)
    
    render_success(
      result[:data].map(&:as_json),
      message: "#{result[:pagination][:total_count]} logs de auditoría encontrados"
    ).merge(pagination: result[:pagination])
  end

  # GET /api/v1/audit_logs/search?q=query
  def search
    query = params[:q]&.strip
    
    if query.blank?
      return render_error('Query parameter is required', status: :bad_request)
    end
    
    @audit_logs = AuditLog.search(query)
    @audit_logs = filter_by_date_range(@audit_logs)
    @audit_logs = @audit_logs.recent
    
    result = paginate_collection(@audit_logs)
    
    render_success(
      result[:data].map(&:as_json),
      message: "#{result[:pagination][:total_count]} logs encontrados para '#{query}'"
    ).merge(pagination: result[:pagination])
  end

  # GET /api/v1/audit_logs/:id
  def show
    render_success(
      @audit_log.as_json(include: {
        child_logs: { 
          only: [:id, :event_id, :action, :resource_type, :occurred_at, :severity],
          methods: [:duration_in_seconds]
        },
        parent_logs: { 
          only: [:id, :event_id, :action, :resource_type, :occurred_at, :severity] 
        }
      })
    )
  end

  # POST /api/v1/audit_logs
  def create
    @audit_log = AuditLog.new(audit_log_params)
    
    # Enriquecer con metadatos de request
    @audit_log.assign_attributes(@request_metadata.slice(
      :correlation_id, :ip_address, :user_id, :user_type
    ))
    
    if @audit_log.save
      render_success(
        @audit_log.as_json,
        status: :created,
        message: 'Log de auditoría creado exitosamente'
      )
    else
      render_error(
        'Error al crear el log de auditoría',
        errors: @audit_log.errors.full_messages
      )
    end
  end

  # GET /api/v1/audit_logs/summary
  def summary
    date_range = parse_date_range
    
    summary_data = {
      total_events: AuditLog.in_date_range(*date_range).count,
      events_by_service: AuditLog.in_date_range(*date_range).group(:service_name).count,
      events_by_severity: AuditLog.in_date_range(*date_range).group(:severity).count,
      events_by_category: AuditLog.in_date_range(*date_range).group(:category).count,
      error_rate: calculate_error_rate(date_range),
      performance_metrics: calculate_performance_metrics(date_range),
      top_users: top_users_by_activity(date_range),
      recent_errors: recent_errors(date_range),
      date_range: {
        start: date_range[0].iso8601,
        end: date_range[1].iso8601
      }
    }
    
    render_success(summary_data, message: 'Resumen de auditoría generado')
  end

  # GET /api/v1/audit_logs/metrics
  def metrics
    date_range = parse_date_range
    
    metrics = {
      events_over_time: events_over_time(date_range),
      service_performance: service_performance_metrics(date_range),
      error_trends: AuditLog.error_trends(7),
      slow_operations: slow_operations(date_range),
      compliance_metrics: compliance_metrics(date_range)
    }
    
    render_success(metrics, message: 'Métricas de auditoría calculadas')
  end

  # GET /api/v1/audit_logs/by_service
  def by_service
    service_name = params[:service_name]
    date_range = parse_date_range
    
    if service_name.blank?
      return render_error('Service name parameter is required', status: :bad_request)
    end
    
    @audit_logs = AuditLog.by_service(service_name).in_date_range(*date_range).recent
    result = paginate_collection(@audit_logs)
    
    service_summary = {
      service_name: service_name,
      total_events: result[:pagination][:total_count],
      performance_avg: AuditLog.service_performance_metrics(service_name, date_range[0]),
      error_rate: calculate_service_error_rate(service_name, date_range)
    }
    
    render_success({
      logs: result[:data].map(&:as_json),
      summary: service_summary
    }).merge(pagination: result[:pagination])
  end

  # GET /api/v1/audit_logs/by_action
  def by_action
    action = params[:action_name]
    date_range = parse_date_range
    
    if action.blank?
      return render_error('Action parameter is required', status: :bad_request)
    end
    
    @audit_logs = AuditLog.by_action(action).in_date_range(*date_range).recent
    result = paginate_collection(@audit_logs)
    
    action_analytics = {
      action: action,
      total_executions: result[:pagination][:total_count],
      services_using: @audit_logs.distinct.pluck(:service_name),
      avg_duration: @audit_logs.average(:duration_ms)&.round(2),
      success_rate: calculate_action_success_rate(action, date_range)
    }
    
    render_success({
      logs: result[:data].map(&:as_json),
      analytics: action_analytics
    }).merge(pagination: result[:pagination])
  end

  # GET /api/v1/audit_logs/by_date_range
  def by_date_range
    date_range = parse_date_range
    
    @audit_logs = AuditLog.in_date_range(*date_range).recent
    @audit_logs = filter_by_service(@audit_logs)
    @audit_logs = filter_by_action(@audit_logs)
    @audit_logs = filter_by_severity(@audit_logs)
    
    result = paginate_collection(@audit_logs)
    
    daily_breakdown = daily_events_breakdown(date_range)
    
    render_success({
      logs: result[:data].map(&:as_json),
      daily_breakdown: daily_breakdown,
      date_range: {
        start: date_range[0].iso8601,
        end: date_range[1].iso8601
      }
    }).merge(pagination: result[:pagination])
  end

  private

  def set_audit_log
    @audit_log = AuditLog.find(params[:id])
  end

  def audit_log_params
    params.require(:audit_log).permit(
      :service_name, :service_version, :environment,
      :action, :resource_type, :resource_id,
      :user_email, :user_type,
      :http_method, :endpoint, :request_params, :response_body, :response_status,
      :description, :severity, :category, :status,
      :sensitive_data, :pii_data, :duration_ms, :memory_usage_mb,
      :error_message, :error_backtrace, :error_class,
      :occurred_at, :metadata, :changes,
      compliance_tags: []
    )
  end

  def parse_date_range
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 7.days.ago.to_date
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    
    [start_date.beginning_of_day, end_date.end_of_day]
  rescue Date::Error
    [7.days.ago.beginning_of_day, Time.current.end_of_day]
  end

  def filter_by_service(logs)
    return logs unless params[:service_name].present?
    logs.by_service(params[:service_name])
  end

  def filter_by_action(logs)
    return logs unless params[:action].present?
    logs.by_action(params[:action])
  end

  def filter_by_severity(logs)
    return logs unless params[:severity].present?
    logs.by_severity(params[:severity])
  end

  def filter_by_category(logs)
    return logs unless params[:category].present?
    logs.by_category(params[:category])
  end

  def filter_by_user(logs)
    return logs unless params[:user_id].present?
    logs.by_user(params[:user_id])
  end

  def filter_by_date_range(logs)
    date_range = parse_date_range
    logs.in_date_range(*date_range)
  end

  def filter_by_resource(logs)
    return logs unless params[:resource_type].present?
    logs.by_resource(params[:resource_type], params[:resource_id])
  end

  def calculate_error_rate(date_range)
    total = AuditLog.in_date_range(*date_range).count
    errors = AuditLog.in_date_range(*date_range).with_errors.count
    
    total > 0 ? ((errors.to_f / total) * 100).round(2) : 0.0
  end

  def calculate_performance_metrics(date_range)
    logs_with_duration = AuditLog.in_date_range(*date_range).where.not(duration_ms: nil)
    
    return { avg: 0, min: 0, max: 0, count: 0 } if logs_with_duration.empty?
    
    {
      avg_duration_ms: logs_with_duration.average(:duration_ms)&.round(2),
      min_duration_ms: logs_with_duration.minimum(:duration_ms),
      max_duration_ms: logs_with_duration.maximum(:duration_ms),
      total_requests: logs_with_duration.count
    }
  end

  def top_users_by_activity(date_range, limit = 10)
    AuditLog.in_date_range(*date_range)
            .where.not(user_id: nil)
            .group(:user_id, :user_email)
            .count
            .sort_by { |_, count| -count }
            .first(limit)
            .map { |(user_id, email), count| { user_id: user_id, email: email, event_count: count } }
  end

  def recent_errors(date_range, limit = 5)
    AuditLog.in_date_range(*date_range)
            .with_errors
            .recent
            .limit(limit)
            .pluck(:id, :service_name, :action, :error_message, :occurred_at)
            .map do |id, service, action, error, time|
              {
                id: id,
                service_name: service,
                action: action,
                error_message: error&.truncate(100),
                occurred_at: time
              }
            end
  end

  def events_over_time(date_range)
    AuditLog.in_date_range(*date_range)
            .group_by_hour(:occurred_at)
            .count
            .transform_keys { |time| time.iso8601 }
  end

  def service_performance_metrics(date_range)
    AuditLog.in_date_range(*date_range)
            .where.not(duration_ms: nil)
            .group(:service_name)
            .average(:duration_ms)
            .transform_values { |avg| avg&.round(2) }
  end

  def slow_operations(date_range, threshold = 1000)
    AuditLog.in_date_range(*date_range)
            .slow_operations(threshold)
            .group(:service_name, :action)
            .average(:duration_ms)
            .transform_values { |avg| avg&.round(2) }
  end

  def compliance_metrics(date_range)
    {
      total_compliance_events: AuditLog.in_date_range(*date_range).category_compliance.count,
      sensitive_data_events: AuditLog.in_date_range(*date_range).where(sensitive_data: true).count,
      pii_events: AuditLog.in_date_range(*date_range).where(pii_data: true).count,
      compliance_by_service: AuditLog.in_date_range(*date_range)
                                    .category_compliance
                                    .group(:service_name)
                                    .count
    }
  end

  def daily_events_breakdown(date_range)
    AuditLog.in_date_range(*date_range)
            .group_by_day(:occurred_at)
            .group(:severity)
            .count
            .group_by { |(date, _severity), _count| date }
            .transform_values do |day_data|
              day_data.transform_keys { |(_date, severity)| severity }
                      .transform_values { |count| count }
            end
  end

  def calculate_service_error_rate(service_name, date_range)
    total = AuditLog.by_service(service_name).in_date_range(*date_range).count
    errors = AuditLog.by_service(service_name).in_date_range(*date_range).with_errors.count
    
    total > 0 ? ((errors.to_f / total) * 100).round(2) : 0.0
  end

  def calculate_action_success_rate(action, date_range)
    total = AuditLog.by_action(action).in_date_range(*date_range).count
    successful = AuditLog.by_action(action).in_date_range(*date_range).successful.count
    
    total > 0 ? ((successful.to_f / total) * 100).round(2) : 0.0
  end
end