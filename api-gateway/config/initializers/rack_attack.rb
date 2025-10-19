# Rate Limiting Configuration using Rack::Attack
require 'rack/attack'

# Enable Rack::Attack
Rails.application.config.middleware.use Rack::Attack

# Configure Redis store for rate limiting (if available)
if Rails.env.production?
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1')
  )
else
  # Use memory store for development/test
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

# Rate limiting rules
class Rack::Attack
  # General API rate limiting
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end
  
  # Authentication endpoint rate limiting (stricter)
  throttle('auth/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/auth/')
  end
  
  # Rate limiting by API key if present
  throttle('api/key', limit: 1000, period: 1.hour) do |req|
    req.env['HTTP_X_API_KEY'] if req.path.start_with?('/api/')
  end
  
  # Block suspicious IPs (can be configured via environment)
  blocklist('block suspicious ips') do |req|
    # Block IPs that are in a blocklist
    ENV['BLOCKED_IPS']&.split(',')&.include?(req.ip)
  end
  
  # Safelist localhost and internal networks in development
  safelist('allow localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip || req.ip.start_with?('192.168.', '10.', '172.')
  end if Rails.env.development?
  
  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{
        error: 'Rate limit exceeded',
        message: 'Too many requests. Please try again later.',
        retry_after: retry_after
      }.to_json]
    ]
  end
  
  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    [
      403,
      { 'Content-Type' => 'application/json' },
      [{
        error: 'Forbidden',
        message: 'Your IP address has been blocked'
      }.to_json]
    ]
  end
end

# Logging for rate limiting events
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]
  case req.env['rack.attack.match_type']
  when :throttle
    Rails.logger.warn "Rate limit exceeded for IP: #{req.ip}, Path: #{req.path}"
  when :blocklist
    Rails.logger.error "Blocked request from IP: #{req.ip}, Path: #{req.path}"
  when :safelist
    Rails.logger.debug "Safelisted request from IP: #{req.ip}, Path: #{req.path}"
  end
end

Rails.logger.info "Rack::Attack rate limiting configured"