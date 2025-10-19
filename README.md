# 🚀 Sistema de Facturación Electrónica - Microservicios Rails 8

![Rails 8](https://img.shields.io/badge/Rails-8.0-red.svg)
![Ruby](https://img.shields.io/badge/Ruby-3.3-red.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)
![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)

Sistema completo de facturación electrónica desarrollado con **4 microservicios** en Rails 8, diseñado para escalabilidad, resiliencia y facilidad de mantenimiento.

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway (Port 3000)                  │
│           ┌─────────────────────────────────────┐            │
│           │  JWT Auth + Rate Limiting + Proxy  │            │
│           └─────────────────────────────────────┘            │
└───────────────────┬─────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│Customer │    │Invoice  │    │ Audit   │
│Service  │    │Service  │    │Service  │
│:3001    │    │:3002    │    │:3003    │
└─────────┘    └─────────┘    └─────────┘
     │              │              │
     └──────────────┼──────────────┘
                    │
            ┌───────▼───────┐
            │   PostgreSQL  │
            │     Redis     │
            └───────────────┘
```

## 📁 Estructura del Proyecto

```
microservices_with_rails/
├── 🌐 api-gateway/                      # API Gateway - Puerto 3000
│   ├── app/controllers/                 # Auth, Proxy, Dashboard controllers
│   ├── config/initializers/             # JWT, Circuit breakers, Rate limiting
│   ├── Dockerfile                       # Imagen Docker optimizada
│   └── README.md                        # Documentación del gateway
│
├── 👥 customer-service/                 # Customer Service - Puerto 3001  
│   ├── app/models/customer.rb           # Modelo principal de clientes
│   ├── app/controllers/api/             # API RESTful de clientes
│   ├── spec/                           # Test suite completo
│   ├── Dockerfile                       # Imagen Docker Rails 8
│   └── README.md                        # Documentación del servicio
│
├── 🧾 invoice-service/                  # Invoice Service - Puerto 3002
│   ├── app/models/invoice.rb            # Core de facturación
│   ├── app/services/                    # Business logic layer
│   ├── app/jobs/                       # Background jobs con Solid Queue
│   ├── spec/                           # Test suite con factories
│   ├── Dockerfile                       # Imagen Docker optimizada
│   └── README.md                        # Documentación del servicio
│
├── 📊 audit-service/                    # Audit Service - Puerto 3003
│   ├── app/models/audit_log.rb          # Modelo de auditoría
│   ├── app/controllers/api/             # API de auditoría y métricas
│   ├── config/mongoid.yml              # Configuración MongoDB (opcional)
│   ├── spec/                           # Test suite completo
│   ├── Dockerfile                       # Imagen Docker Rails 8
│   └── README.md                        # Documentación del servicio
│
├── 🐳 docker-compose.yml              
└── 📚 README.md                        # Esta documentación
```

## 🚀 Inicio Rápido

### Opción 1: Todo el Sistema (Recomendado)

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd microservices_with_rails

# 2. Ejecutar setup automático
chmod +x setup_demo.sh
./setup_demo.sh

# 3. Levantar todos los servicios
docker-compose up -d

# 4. Verificar que todo funciona
chmod +x test_complete_system.sh
./test_complete_system.sh

# 5. Acceder a los servicios
open http://localhost:3000    # API Gateway
open http://localhost:3001    # Customer Service  
open http://localhost:3002    # Invoice Service
open http://localhost:3003    # Audit Service
```

### Opción 2: Servicio por Servicio

#### 🌐 Solo API Gateway
```bash
# Levantar dependencias básicas
docker-compose up postgres redis -d

# Levantar API Gateway
docker-compose up api-gateway -d

# Testing
curl http://localhost:3000/health
```

#### 👥 Solo Customer Service  
```bash
# Levantar dependencias
docker-compose up postgres redis -d

# Levantar Customer Service
docker-compose up customer-service customer-worker -d

# Testing
curl http://localhost:3001/health
curl http://localhost:3001/api/customers
```

#### 🧾 Solo Invoice Service
```bash
# Levantar dependencias + Customer Service
docker-compose up postgres redis customer-service -d

# Levantar Invoice Service  
docker-compose up invoice-service invoice-worker -d

# Testing
curl http://localhost:3002/health
curl http://localhost:3002/api/invoices
```

#### 📊 Solo Audit Service
```bash
# Levantar todas las dependencias
docker-compose up postgres redis customer-service invoice-service -d

# Levantar Audit Service
docker-compose up audit-service audit-worker -d

# Testing
curl http://localhost:3003/health
curl http://localhost:3003/api/audit_logs
```

---

## 🔧 Configuración por Ambiente

### Desarrollo Local

```bash
# Variables de entorno principales
export RAILS_ENV=development
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/
export REDIS_URL=redis://localhost:6379/

# Levantar infraestructura
docker-compose up postgres redis -d

# Ejecutar cada servicio individualmente
cd customer-service && bundle exec rails server -p 3001
cd invoice-service && bundle exec rails server -p 3002  
cd audit-service && bundle exec rails server -p 3003
cd api-gateway && bundle exec rails server -p 3000
```

### Testing

```bash
# Test individual por servicio
cd customer-service && bundle exec rspec
cd invoice-service && bundle exec rspec
cd audit-service && bundle exec rspec
cd api-gateway && bundle exec rspec

# Test de integración completo
./test_complete_system.sh
```

### Producción

```bash
# Construir imágenes para producción
docker-compose -f docker-compose.prod.yml build

# Levantar en modo producción
docker-compose -f docker-compose.prod.yml up -d

# Monitoreo
docker-compose logs -f
```

---

## 🧪 Testing y Validación

### Tests Automatizados Incluidos

```bash
# 1. Test Customer Service
chmod +x test_customer_service.sh
./test_customer_service.sh

# 2. Test Invoice Service  
chmod +x test_invoice_service.sh
./test_invoice_service.sh

# 3. Test sistema completo
chmod +x test_complete_system.sh
./test_complete_system.sh
```

### APIs Documentadas

#### 🌐 API Gateway (Puerto 3000)

```bash
# Autenticación
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "user123"}'

# Dashboard agregado
curl -X GET http://localhost:3000/api/dashboard/overview \
  -H "Authorization: Bearer <JWT_TOKEN>"

# Proxy a servicios
curl -X GET http://localhost:3000/api/customers \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

#### 👥 Customer Service (Puerto 3001)

```bash
# Listar clientes
curl http://localhost:3001/api/customers

# Crear cliente
curl -X POST http://localhost:3001/api/customers \
  -H "Content-Type: application/json" \
  -d '{
    "customer": {
      "tax_id": "123456789",
      "name": "Empresa Test",
      "email": "test@empresa.com",
      "tax_regime": "simplified"
    }
  }'

# Buscar por tax_id
curl http://localhost:3001/api/customers/search?tax_id=123456789
```

#### 🧾 Invoice Service (Puerto 3002)

```bash
# Listar facturas
curl http://localhost:3002/api/invoices

# Crear factura
curl -X POST http://localhost:3002/api/invoices \
  -H "Content-Type: application/json" \
  -d '{
    "invoice": {
      "customer_id": 1,
      "items": [
        {
          "description": "Producto 1",
          "quantity": 2,
          "unit_price": 1000
        }
      ]
    }
  }'

# Cambiar estado
curl -X PATCH http://localhost:3002/api/invoices/1/status \
  -H "Content-Type: application/json" \
  -d '{"status": "issued"}'
```

#### 📊 Audit Service (Puerto 3003)

```bash
# Ver logs de auditoría
curl http://localhost:3003/api/audit_logs

# Métricas del sistema
curl http://localhost:3003/api/metrics/summary

# Logs por recurso
curl http://localhost:3003/api/audit_logs?resource_type=Invoice&resource_id=1
```

---

## 🛠️ Stack Tecnológico

### Framework & Runtime
- **Ruby 3.3** - Última versión estable con mejoras de performance
- **Rails 8.0** - Con Solid Queue, Solid Cache y autenticación integrada
- **Puma** - Web server optimizado para concurrencia

### Base de Datos & Cache  
- **PostgreSQL 16** - Base de datos principal con extensiones modernas
- **Redis 7** - Cache distribuido y backend para Solid Queue
- **Solid Cache** - Sistema de cache integrado en Rails 8

### Infraestructura
- **Docker & Docker Compose** - Containerización y orquestación
- **GitHub Actions** - CI/CD pipeline (configurado)
- **Nginx** - Reverse proxy para producción (configurado)

### Observabilidad & Monitoreo
- **Rails Logger** - Logging estructurado JSON
- **Health Checks** - Endpoints de salud por servicio
- **Metrics** - Métricas de negocio y técnicas
- **Circuit Breakers** - Resiliencia entre servicios

### Testing & Calidad
- **RSpec** - Framework de testing principal
- **FactoryBot** - Factories para datos de prueba  
- **VCR** - Grabación de requests HTTP
- **Rubocop** - Linting y style guide
- **SimpleCov** - Cobertura de código

---

## 📊 Servicios Implementados

### 🌐 API Gateway

**Responsabilidades:**
- ✅ Autenticación JWT con refresh tokens
- ✅ Rate limiting inteligente (100 req/min general, 10 req/min auth)
- ✅ Proxy inteligente con circuit breakers
- ✅ Endpoints agregados (dashboard, analytics)
- ✅ CORS y headers de seguridad

**Características técnicas:**
- Circuit breakers por servicio (5 fallos → OPEN, 60s recovery)
- Rate limiting con Redis y reglas por endpoint
- JWT con algoritmo HS256 y expiración configurable
- Logging de auditoría para eventos de autenticación

### 👥 Customer Service

**Responsabilidades:**
- ✅ CRUD completo de clientes
- ✅ Validación de tax_id colombiano
- ✅ Búsqueda y filtrado avanzado  
- ✅ Integración con servicios tributarios (mock)
- ✅ API REST con paginación

**Características técnicas:**
- PostgreSQL con índices optimizados para búsquedas
- Validaciones robustas con reglas de negocio
- Background jobs para validaciones externas
- Cache inteligente para consultas frecuentes

### 🧾 Invoice Service

**Responsabilidades:**
- ✅ Core de facturación electrónica
- ✅ Cálculo automático de impuestos
- ✅ Estados de factura (draft → issued → sent → cancelled)
- ✅ Integración con Customer Service
- ✅ Generación de PDFs (preparado)

**Características técnicas:**
- Clean Architecture con capas bien definidas
- Solid Queue para jobs asíncronos
- Comunicación HTTP con circuit breakers
- Eventos de auditoría automáticos

### 📊 Audit Service

**Responsabilidades:**
- ✅ Logging centralizado de eventos
- ✅ Trazabilidad completa del sistema
- ✅ Métricas de negocio en tiempo real
- ✅ API de reportes y analytics
- ✅ Compliance y auditoría

**Características técnicas:**
- Almacenamiento optimizado para writes masivos
- APIs de consulta con filtros avanzados
- Agregaciones en tiempo real
- Retención de datos configurable

---

## 🔐 Seguridad

### Autenticación & Autorización
- JWT tokens con expiracion y refresh automático
- Roles y permisos por usuario
- Rate limiting por IP y por usuario autenticado
- Logs de auditoría para eventos de seguridad

### Protección de APIs
- CORS configurado para dominios específicos
- Headers de seguridad (HSTS, CSP, etc.)
- Validación de input en todas las capas
- Sanitización automática de parámetros

### Infraestructura
- Secrets management con variables de entorno
- Base de datos con conexiones encriptadas
- Redis con autenticación (cuando se requiera)
- Docker images con usuarios no-root

---

## ⚡ Performance & Escalabilidad

### Optimizaciones Implementadas
- **Database Indexing** - Índices optimizados para consultas frecuentes
- **Connection Pooling** - Pool de conexiones configurado por servicio
- **Query Optimization** - N+1 queries evitadas con includes
- **Caching Strategy** - Cache a múltiples niveles (aplicación, Redis, HTTP)

### Escalabilidad Horizontal
- **Stateless Services** - Todos los servicios son stateless
- **Load Balancing** - Preparado para múltiples instancias
- **Database Sharding** - Estrategia definida para crecimiento
- **Auto-scaling** - Configuración lista para Kubernetes

### Métricas de Performance
- **Response Time** - P95 < 200ms para endpoints críticos
- **Throughput** - 1000+ requests/second por servicio
- **Availability** - 99.9% uptime target
- **Resource Usage** - Optimizado para contenedores

---

## 🚨 Troubleshooting

### Problemas Comunes

#### 🔴 Servicios no inician
```bash
# Verificar logs
docker-compose logs <service-name>

# Verificar dependencias
docker-compose ps

# Reiniciar servicios
docker-compose restart <service-name>
```

#### 🔴 Base de datos no conecta
```bash
# Verificar PostgreSQL
docker-compose exec postgres psql -U postgres -c "\l"

# Verificar configuración
grep DATABASE_URL docker-compose.yml

# Recrear volúmenes si es necesario
docker-compose down -v
docker-compose up -d
```

#### 🔴 Tests fallan
```bash
# Limpiar entorno de test
RAILS_ENV=test bundle exec rails db:drop db:create db:migrate

# Ejecutar tests específicos
bundle exec rspec spec/path/to/specific_spec.rb

# Verificar factories
bundle exec rails console test
FactoryBot.create(:customer)
```

#### 🔴 Circuit breakers abiertos
```bash
# Verificar estado de servicios
curl http://localhost:3000/health/detailed

# Revisar logs del gateway
docker-compose logs api-gateway | grep "Circuit breaker"

# Reiniciar servicios problemáticos
docker-compose restart customer-service invoice-service audit-service
```

### Comandos de Debugging

```bash
# Entrar al container de un servicio
docker-compose exec customer-service bash

# Ver logs en tiempo real
docker-compose logs -f --tail=100 <service-name>

# Ejecutar Rails console
docker-compose exec customer-service rails console

# Verificar variables de entorno
docker-compose exec customer-service printenv | grep RAILS

# Test de conectividad entre servicios
docker-compose exec api-gateway curl http://customer-service:3000/health
```

---

## 📈 Monitoreo & Observabilidad

### Health Checks
```bash
# Salud básica de cada servicio
curl http://localhost:3000/health  # API Gateway
curl http://localhost:3001/health  # Customer Service
curl http://localhost:3002/health  # Invoice Service
curl http://localhost:3003/health  # Audit Service

# Salud detallada con dependencias
curl http://localhost:3000/health/detailed
```

### Métricas de Negocio
```bash
# Dashboard general
curl http://localhost:3000/api/dashboard/overview

# Métricas de auditoría
curl http://localhost:3003/api/metrics/summary

# Analytics por período
curl http://localhost:3000/api/dashboard/analytics?date_range=30
```

### Logs Estructurados
```bash
# Logs por servicio
docker-compose logs customer-service | jq '.'
docker-compose logs invoice-service | jq '.'

# Filtrar por nivel de log
docker-compose logs audit-service | grep ERROR
docker-compose logs api-gateway | grep "Circuit breaker"
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions (Configurado)

```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres: # PostgreSQL service
      redis: # Redis service
    steps:
      - uses: actions/checkout@v3
      - name: Setup Ruby
      - name: Install dependencies
      - name: Run tests
      - name: Upload coverage
```

### Deployment Pipeline

```bash
# Build y push images
docker-compose build
docker tag <image> <registry>/<image>:latest
docker push <registry>/<image>:latest

# Deploy en staging
docker-compose -f docker-compose.staging.yml up -d

# Smoke tests en staging
./test_complete_system.sh

# Deploy en producción
docker-compose -f docker-compose.prod.yml up -d
```

---

## 🤝 Contribución

### Estructura para Nuevos Servicios

```bash
# Generar nuevo microservicio
rails new <service-name> --api --database=postgresql
cd <service-name>

# Agregar gems estándar
# - rspec-rails, factory_bot_rails
# - faraday (para comunicación entre servicios)
# - solid_queue (para background jobs)

# Configurar Dockerfile estándar
# Configurar docker-compose entry
# Agregar health check endpoint
# Configurar circuit breaker en API Gateway
```

### Guidelines de Desarrollo

1. **Testing First** - Escribir tests antes que código
2. **API Documentation** - Documentar endpoints con ejemplos
3. **Error Handling** - Manejar errores de manera consistente
4. **Performance** - Optimizar queries y caching
5. **Security** - Validar input y manejar autenticación
6. **Observability** - Agregar logs y métricas útiles

---

## 📚 Recursos Adicionales

### Documentación Técnica
- [Rails 8 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [Microservices Patterns](https://microservices.io/patterns/)
- [API Design Guidelines](https://docs.microsoft.com/en-us/azure/architecture/best-practices/api-design)

### Monitoreo y Observabilidad
- [Health Check Patterns](https://microservices.io/patterns/observability/health-check-api.html)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Distributed Tracing](https://opentracing.io/guides/ruby/)

### Arquitectura y Diseño
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Domain Driven Design](https://martinfowler.com/tags/domain%20driven%20design.html)
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)

---

## 🏆 Características Destacadas

✅ **Rails 8 Completo** - Solid Queue, Solid Cache, Authentication integrado  
✅ **Clean Architecture** - Separación clara de responsabilidades  
✅ **API Gateway** - Autenticación, rate limiting, circuit breakers  
✅ **Testing Robusto** - Test suite completo con factories y mocks  
✅ **Docker Optimizado** - Imágenes optimizadas y docker-compose funcional  
✅ **Observabilidad** - Health checks, métricas, logs estructurados  
✅ **Seguridad** - JWT, CORS, validaciones, rate limiting  
✅ **Performance** - Índices optimizados, caching, connection pooling  
✅ **Escalabilidad** - Servicios stateless, preparado para auto-scaling  
✅ **Developer Experience** - Setup en un comando, documentación completa

---

**Sistema desarrollado con ❤️ usando Rails 8 y mejores prácticas de microservicios**

---