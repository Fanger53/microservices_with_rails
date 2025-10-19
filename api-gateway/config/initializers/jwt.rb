# JWT Configuration for API Gateway Authentication
require 'jwt'

Rails.application.configure do
  # JWT Secret Key - should be set via environment variable in production
  config.x.jwt_secret = ENV.fetch('JWT_SECRET_KEY') { Rails.application.secret_key_base }
  
  # JWT Algorithm
  config.x.jwt_algorithm = ENV.fetch('JWT_ALGORITHM', 'HS256')
  
  # JWT Expiration (default 24 hours)
  config.x.jwt_expiration = ENV.fetch('JWT_EXPIRATION_HOURS', '24').to_i.hours
  
  # JWT Issuer
  config.x.jwt_issuer = ENV.fetch('JWT_ISSUER', 'api-gateway')
  
  # JWT Audience
  config.x.jwt_audience = ENV.fetch('JWT_AUDIENCE', 'microservices')
end

# JWT Service for encoding and decoding tokens
class JWTService
  class << self
    def encode(payload, exp = nil)
      exp ||= Rails.application.config.x.jwt_expiration.from_now.to_i
      
      payload[:exp] = exp
      payload[:iat] = Time.current.to_i
      payload[:iss] = Rails.application.config.x.jwt_issuer
      payload[:aud] = Rails.application.config.x.jwt_audience
      
      JWT.encode(payload, jwt_secret, jwt_algorithm)
    end
    
    def decode(token)
      decoded = JWT.decode(
        token,
        jwt_secret,
        true,
        {
          algorithm: jwt_algorithm,
          verify_iss: true,
          verify_aud: true,
          iss: Rails.application.config.x.jwt_issuer,
          aud: Rails.application.config.x.jwt_audience,
          verify_expiration: true
        }
      )
      
      HashWithIndifferentAccess.new(decoded[0])
    rescue JWT::DecodeError => e
      Rails.logger.warn "JWT decode error: #{e.message}"
      nil
    end
    
    def valid?(token)
      !!decode(token)
    end
    
    private
    
    def jwt_secret
      Rails.application.config.x.jwt_secret
    end
    
    def jwt_algorithm
      Rails.application.config.x.jwt_algorithm
    end
  end
end

Rails.logger.info "JWT Service initialized with algorithm: #{Rails.application.config.x.jwt_algorithm}"