# Circuit Breaker Configuration for API Gateway
# Manages failures when communicating with backend services

class CircuitBreaker
  class CircuitBreakerError < StandardError; end
  
  # Circuit breaker states
  CLOSED = :closed
  OPEN = :open
  HALF_OPEN = :half_open
  
  attr_reader :failure_count, :last_failure_time, :state
  
  def initialize(failure_threshold: 5, timeout: 30, recovery_timeout: 60)
    @failure_threshold = failure_threshold
    @timeout = timeout
    @recovery_timeout = recovery_timeout
    @failure_count = 0
    @last_failure_time = nil
    @state = CLOSED
    @mutex = Mutex.new
  end
  
  def call(&block)
    @mutex.synchronize do
      case @state
      when CLOSED
        execute_request(&block)
      when OPEN
        if should_attempt_reset?
          @state = HALF_OPEN
          Rails.logger.info "Circuit breaker transitioning to HALF_OPEN"
          execute_request(&block)
        else
          raise CircuitBreakerError, "Circuit breaker is OPEN"
        end
      when HALF_OPEN
        execute_request(&block)
      end
    end
  end
  
  private
  
  def execute_request(&block)
    result = block.call
    on_success
    result
  rescue => e
    on_failure
    raise e
  end
  
  def on_success
    @failure_count = 0
    @last_failure_time = nil
    if @state == HALF_OPEN
      @state = CLOSED
      Rails.logger.info "Circuit breaker reset to CLOSED"
    end
  end
  
  def on_failure
    @failure_count += 1
    @last_failure_time = Time.current
    
    if @failure_count >= @failure_threshold && @state == CLOSED
      @state = OPEN
      Rails.logger.warn "Circuit breaker opened after #{@failure_count} failures"
    elsif @state == HALF_OPEN
      @state = OPEN
      Rails.logger.warn "Circuit breaker reopened during half-open test"
    end
  end
  
  def should_attempt_reset?
    @last_failure_time && (Time.current - @last_failure_time) >= @recovery_timeout
  end
end

# Global circuit breakers for each service
Rails.application.configure do
  config.x.circuit_breakers = {
    customer_service: CircuitBreaker.new(
      failure_threshold: Rails.env.production? ? 5 : 3,
      timeout: 10,
      recovery_timeout: Rails.env.production? ? 60 : 30
    ),
    invoice_service: CircuitBreaker.new(
      failure_threshold: Rails.env.production? ? 5 : 3,
      timeout: 10,
      recovery_timeout: Rails.env.production? ? 60 : 30
    ),
    audit_service: CircuitBreaker.new(
      failure_threshold: Rails.env.production? ? 3 : 2,
      timeout: 5,
      recovery_timeout: Rails.env.production? ? 30 : 15
    )
  }
end

Rails.logger.info "Circuit breakers initialized for all services"