# API Gateway Service Configuration

Welcome to the API Gateway for the Electronic Invoicing Microservices System!

## Overview

The API Gateway serves as the single entry point for all client requests to the microservices architecture. It provides authentication, authorization, rate limiting, and request routing to the appropriate backend services.

## Architecture

```
[Client] → [API Gateway:3000] → [Customer Service:3001]
                              → [Invoice Service:3002]
                              → [Audit Service:3003]
```

## Features

### 🔐 Authentication & Authorization
- JWT-based authentication with configurable expiration
- User registration and login endpoints
- Role-based access control
- Token refresh mechanism

### 🛡️ Security
- Rate limiting with Rack::Attack
- CORS configuration for cross-origin requests
- Circuit breakers for service resilience
- Request/response logging and monitoring

### 🔄 Service Proxy
- Intelligent request routing to backend services
- Health checking of downstream services
- Automatic retry and fallback mechanisms
- Load balancing capabilities

### 📊 Aggregated Endpoints
- Dashboard overview combining data from all services
- Customer-invoice relationship queries
- Analytics and reporting across services
- Real-time health status monitoring

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/api_gateway_development

# Redis (for rate limiting)
REDIS_URL=redis://redis:6379/3

# JWT Configuration
JWT_SECRET_KEY=your_secret_key_here
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# Service URLs
CUSTOMER_SERVICE_URL=http://customer-service:3001
INVOICE_SERVICE_URL=http://invoice-service:3002
AUDIT_SERVICE_URL=http://audit-service:3003

# Rate Limiting
BLOCKED_IPS=192.168.1.100,10.0.0.5

# Monitoring
RAILS_LOG_LEVEL=info
```

## API Endpoints

### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `POST /auth/refresh` - Refresh JWT token
- `POST /auth/logout` - User logout
- `GET /auth/me` - Get current user info

### Health & Monitoring
- `GET /health` - Basic health check
- `GET /health/detailed` - Detailed health with service status

### Service Proxy
- `GET|POST|PUT|DELETE /api/customers/*` → Customer Service
- `GET|POST|PUT|DELETE /api/invoices/*` → Invoice Service
- `GET|POST|PUT|DELETE /api/audit_logs/*` → Audit Service

### Aggregated Data
- `GET /api/dashboard/overview` - System overview
- `GET /api/dashboard/customer_invoices/:customer_id` - Customer with invoices
- `GET /api/dashboard/invoice_details/:invoice_id` - Invoice with audit logs
- `GET /api/dashboard/analytics` - Cross-service analytics

## Usage Examples

### Authentication
```bash
# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "user123"}'

# Use JWT token in subsequent requests
curl -X GET http://localhost:3000/api/customers \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Proxy Requests
```bash
# Get customers (proxied to customer service)
curl -X GET http://localhost:3000/api/customers \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Create invoice (proxied to invoice service)
curl -X POST http://localhost:3000/api/invoices \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "total_amount": 1000}'
```

### Aggregated Data
```bash
# Dashboard overview
curl -X GET http://localhost:3000/api/dashboard/overview \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Customer with invoices
curl -X GET http://localhost:3000/api/dashboard/customer_invoices/1 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Rate Limiting

The API Gateway implements rate limiting to protect backend services:

- **General API**: 100 requests per minute per IP
- **Authentication**: 10 requests per minute per IP
- **Authenticated users**: 1000 requests per hour per API key

Rate limit headers are included in responses:
- `X-RateLimit-Limit`: Request limit
- `X-RateLimit-Remaining`: Remaining requests
- `Retry-After`: Seconds until reset (when throttled)

## Circuit Breakers

Each backend service has its own circuit breaker:

- **Failure Threshold**: 5 failures (3 in development)
- **Timeout**: 30 seconds
- **Recovery Time**: 60 seconds (30 in development)

Circuit breaker states:
- **CLOSED**: Normal operation
- **OPEN**: Service unavailable, requests fail fast
- **HALF-OPEN**: Testing service recovery

## Error Handling

The gateway provides consistent error responses:

```json
{
  "success": false,
  "error": "Service unavailable",
  "message": "The requested service is temporarily unavailable",
  "request_id": "uuid-request-id"
}
```

HTTP Status Codes:
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden (rate limited)
- `404` - Not Found
- `429` - Too Many Requests
- `502` - Bad Gateway (service connection error)
- `503` - Service Unavailable (circuit breaker open)
- `504` - Gateway Timeout

## Development

### Running Locally
```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Start server
rails server -p 3000

# Run tests
rails test
```

### Docker Development
```bash
# Build and run with Docker Compose
docker-compose up api-gateway

# View logs
docker-compose logs -f api-gateway
```

## Production Deployment

### Security Checklist
- [ ] Set strong JWT_SECRET_KEY
- [ ] Configure proper CORS origins
- [ ] Set up SSL/TLS termination
- [ ] Configure firewall rules
- [ ] Set up monitoring and alerting
- [ ] Enable request logging
- [ ] Configure rate limiting per environment

### Scaling Considerations
- Run multiple gateway instances behind a load balancer
- Use Redis cluster for distributed rate limiting
- Monitor circuit breaker metrics
- Set up health checks for auto-scaling

## Monitoring

The gateway provides metrics and logging for:
- Request/response times
- Error rates by service
- Circuit breaker state changes
- Rate limiting events
- Authentication attempts

Integration with monitoring tools:
- Prometheus metrics endpoint (if configured)
- Structured JSON logging
- Health check endpoints for load balancers

## Troubleshooting

### Common Issues

1. **Service Unavailable (503)**
   - Check backend service health
   - Verify circuit breaker status
   - Check network connectivity

2. **Rate Limited (429)**
   - Check IP address limits
   - Verify API key configuration
   - Review rate limiting rules

3. **Authentication Errors (401)**
   - Verify JWT token validity
   - Check token expiration
   - Confirm JWT secret configuration

### Debug Commands
```bash
# Check service health
curl http://localhost:3000/health/detailed

# View circuit breaker status
rails console
Rails.application.config.x.circuit_breakers.each { |k,v| puts "#{k}: #{v.state}" }

# Test rate limiting
for i in {1..10}; do curl http://localhost:3000/api/customers; done
```

---

Built with ❤️ using Rails 8 and modern microservices patterns.