class AuditSummary < ApplicationRecord
  # Rails 8 - Enhanced enums
  enum :summary_type, {
    daily: 0,
    hourly: 1,
    service: 2,
    user: 3,
    action: 4,
    monthly: 5
  }, prefix: true, validate: true

  # Validations
  validates :summary_type, :dimension_key, :dimension_value, presence: true
  validates :summary_date, presence: true, if: -> { daily_summary_type? || monthly_summary_type? }
  validates :summary_hour, presence: true, inclusion: { in: 0..23 }, if: -> { hourly_summary_type? }
  
  validates :total_events, :success_events, :error_events, :warning_events,
            numericality: { greater_than_or_equal_to: 0 }
  
  validates :avg_duration_ms, :max_duration_ms, :min_duration_ms,
            numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  # Unique constraint
  validates :summary_date, uniqueness: { 
    scope: [:summary_type, :dimension_key, :dimension_value, :summary_hour],
    message: 'summary already exists for this time period and dimension'
  }

  # Scopes
  scope :by_type, ->(type) { where(summary_type: type) }
  scope :by_dimension, ->(key, value) { where(dimension_key: key, dimension_value: value) }
  scope :by_date_range, ->(start_date, end_date) { 
    where(summary_date: start_date..end_date) 
  }
  scope :recent, -> { order(summary_date: :desc, summary_hour: :desc) }

  # Class methods for aggregation
  class << self
    def create_daily_summary(date, service_name)
      logs = AuditLog.where(
        service_name: service_name,
        occurred_at: date.beginning_of_day..date.end_of_day
      )

      summary_data = calculate_summary_metrics(logs)
      
      create!(
        summary_type: :daily,
        dimension_key: 'service_name',
        dimension_value: service_name,
        summary_date: date,
        **summary_data
      )
    end

    def create_hourly_summary(date, hour, service_name)
      start_time = date.beginning_of_day + hour.hours
      end_time = start_time + 1.hour

      logs = AuditLog.where(
        service_name: service_name,
        occurred_at: start_time..end_time
      )

      summary_data = calculate_summary_metrics(logs)
      
      create!(
        summary_type: :hourly,
        dimension_key: 'service_name',
        dimension_value: service_name,
        summary_date: date,
        summary_hour: hour,
        **summary_data
      )
    end

    def create_user_summary(date, user_id)
      logs = AuditLog.where(
        user_id: user_id,
        occurred_at: date.beginning_of_day..date.end_of_day
      )

      summary_data = calculate_summary_metrics(logs)
      
      create!(
        summary_type: :user,
        dimension_key: 'user_id',
        dimension_value: user_id,
        summary_date: date,
        **summary_data
      )
    end

    private

    def calculate_summary_metrics(logs)
      total_count = logs.count
      success_count = logs.successful.count
      error_count = logs.with_errors.count
      warning_count = logs.severity_warn.count

      durations = logs.where.not(duration_ms: nil).pluck(:duration_ms)
      
      {
        total_events: total_count,
        success_events: success_count,
        error_events: error_count,
        warning_events: warning_count,
        avg_duration_ms: durations.any? ? durations.sum / durations.size.to_f : 0.0,
        max_duration_ms: durations.max || 0.0,
        min_duration_ms: durations.min || 0.0,
        metadata: {
          actions: logs.group(:action).count,
          severities: logs.group(:severity).count,
          categories: logs.group(:category).count,
          response_statuses: logs.where.not(response_status: nil).group(:response_status).count
        }
      }
    end
  end

  # Instance methods
  def error_rate
    return 0.0 if total_events.zero?
    (error_events.to_f / total_events * 100).round(2)
  end

  def success_rate
    return 0.0 if total_events.zero?
    (success_events.to_f / total_events * 100).round(2)
  end

  def average_duration_seconds
    return 0.0 unless avg_duration_ms&.positive?
    (avg_duration_ms / 1000.0).round(3)
  end

  def performance_grade
    case
    when error_rate > 10 then 'F'
    when error_rate > 5 then 'D'
    when error_rate > 2 then 'C'
    when error_rate > 1 then 'B'
    else 'A'
    end
  end

  def as_json(options = {})
    super(options.merge(
      methods: [:error_rate, :success_rate, :average_duration_seconds, :performance_grade]
    ))
  end
end