# Sistema de Facturación Electrónica - FactuMarket S.A.
## Diseño de Arquitectura de Microservicios con Ruby on Rails

### Tabla de Contenidos
1. [Análisis del Problema](#análisis-del-problema)
2. [Microservicios Principales](#microservicios-principales)
3. [Responsabilidades e Interacciones](#responsabilidades-e-interacciones)
4. [Flujo de Comunicación](#flujo-de-comunicación)
5. [Estrategia de Persistencia](#estrategia-de-persistencia)
6. [Aplicación de Principios Arquitectónicos](#aplicación-de-principios-arquitectónicos)
7. [Diagrama de Arquitectura](#diagrama-de-arquitectura)

---

## 1. Análisis del Problema

### Problemas Identificados:
- **Demoras en emisión**: Sistema manual y monolítico
- **Duplicación de datos**: Base de datos central congestionada
- **Falta de trazabilidad**: Eventos de auditoría inadecuados
- **Rigidez tecnológica**: Sistema acoplado sin flexibilidad

### Solución Propuesta:
Arquitectura de microservicios con Rails que permita escalabilidad, mantenibilidad y cumplimiento normativo.

---

## 2. Microservicios Principales

### 2.1 Customer Service (Servicio de Clientes)
**Tecnología:** Ruby on Rails 8.0
**Puerto:** 3001
**Responsabilidad:** Gestión completa del ciclo de vida de clientes

**Funcionalidades:**
- Registro y validación de clientes con autenticación integrada Rails 8
- Actualización de información fiscal con encriptación automática
- Consulta de datos para facturación con cache optimizado
- Validaciones de documentos tributarios con pattern matching

**Nuevas características Rails 8:**
- Solid Queue para procesamiento asíncrono sin Redis dependency
- Authentication built-in para seguridad mejorada
- Automatic encryption para datos sensibles
- Performance boost del 15-20% vs Rails 7

### 2.2 Invoice Service (Servicio de Facturas)
**Tecnología:** Ruby on Rails 8.0
**Puerto:** 3002
**Responsabilidad:** Core del negocio - emisión de facturas electrónicas

**Funcionalidades:**
- Creación y validación de facturas con state machine mejorada
- Cálculos tributarios (IVA, retenciones) con cache automático
- Generación de PDF y XML con Active Storage optimizado
- Estados de factura (borrador, emitida, cancelada) con pattern matching
- Integración futura con DIAN usando circuit breakers

**Mejoras Rails 8:**
- Solid Queue para procesamiento de documentos
- Job chaining automático para flujos complejos
- Circuit breaker pattern integrado
- Error tracking mejorado con context

### 2.3 Audit Service (Servicio de Auditoría)
**Tecnología:** Ruby on Rails 8.0
**Puerto:** 3003
**Responsabilidad:** Trazabilidad y cumplimiento normativo

**Funcionalidades:**
- Registro de eventos del sistema con metadata enriquecida
- Logs de acciones de usuarios con correlation IDs
- Reportes de auditoría con streaming para datasets grandes
- Análisis de patrones de uso con métricas automáticas

**Características Rails 8:**
- Solid Queue con retry exponencial para eventos críticos
- Instrumentación automática con ActiveSupport::Notifications
- Metrics collection integrada con Solid Cache
- Job dependencies para procesamiento complejo

### 2.4 API Gateway (Opcional pero recomendado)
**Tecnología:** Ruby on Rails 7.x o Nginx
**Puerto:** 3000
**Responsabilidad:** Punto único de entrada y coordinación

---

## 3. Responsabilidades e Interacciones

### 3.1 Customer Service
```ruby
# Modelo de dominio principal
class Customer
  # Validaciones de negocio
  validates :tax_id, uniqueness: true, format: /\A\d{8,11}\z/
  validates :email, presence: true, format: URI::MailTo::EMAIL_REGEXP
end

# Casos de uso principales
- CreateCustomer
- UpdateCustomer
- ValidateCustomerForInvoicing
- GetCustomerTaxInfo
```

### 3.2 Invoice Service
```ruby
# Entidad central del negocio
class Invoice
  # Estados del dominio
  enum status: { draft: 0, issued: 1, sent: 2, cancelled: 3 }
  
  # Validaciones críticas
  validates :customer_id, presence: true
  validates :total_amount, numericality: { greater_than: 0 }
end

# Casos de uso críticos
- CreateInvoice
- CalculateTaxes
- GenerateElectronicDocument
- SubmitToDIAN (futuro)
```

### 3.3 Audit Service
```ruby
# Registro de eventos
class AuditEvent
  # Metadatos del evento
  field :event_type, type: String
  field :user_id, type: String
  field :service_name, type: String
  field :timestamp, type: DateTime
  field :metadata, type: Hash
end

# Casos de uso de auditoría
- LogBusinessEvent
- GenerateAuditReport
- TrackUserActions
```

### Patrón de Interacciones:
1. **Cliente → API Gateway → Customer Service**
2. **API Gateway → Invoice Service** (consulta datos de cliente)
3. **Invoice Service → Audit Service** (registra eventos)

---

## 4. Flujo de Comunicación

### 4.1 Comunicación Síncrona (REST)
**Uso:** Operaciones que requieren respuesta inmediata

```ruby
# En Invoice Service - consultando datos de cliente
class CustomerServiceClient
  def find_customer(customer_id)
    response = Faraday.get("#{CUSTOMER_SERVICE_URL}/api/v1/customers/#{customer_id}")
    JSON.parse(response.body) if response.success?
  end
end
```

### 4.2 Comunicación Asíncrona (Solid Queue - Rails 8)
**Uso:** Auditoría y notificaciones sin dependencia externa

```ruby
# Publisher de eventos con Solid Queue (Rails 8)
class EventPublisher
  def self.publish(event_type, payload)
    # Rails 8 - Solid Queue sin Redis dependency
    AuditEventJob.set(
      queue: 'audit_events',
      priority: priority_for(event_type),
      retry: 5
    ).perform_later(event_type, payload, Time.current.to_f)
  end
  
  # Rails 8 - Job chaining para eventos complejos
  def self.publish_with_followup(event_type, payload, followup_jobs = [])
    job = AuditEventJob.perform_later(event_type, payload)
    
    followup_jobs.each do |followup_job|
      job.then(followup_job)
    end
  end
  
  private
  
  def self.priority_for(event_type)
    case event_type
    when 'invoice_cancelled', 'payment_failed' then 10  # Alta prioridad
    when 'invoice_created', 'customer_updated' then 5   # Media prioridad  
    else 1                                              # Baja prioridad
    end
  end
end

# En Invoice Service
EventPublisher.publish('invoice_created', {
  invoice_id: @invoice.id,
  customer_id: @invoice.customer_id,
  amount: @invoice.total_amount,
  correlation_id: Current.request_id  # Rails 8 feature
})

# Rails 8 - Parallel job execution para eventos complejos
EventPublisher.publish_with_followup('invoice_created', invoice_data, [
  EmailNotificationJob.set(wait: 1.minute),
  TaxReportingJob.set(wait: 5.minutes),
  CustomerStatsJob.set(wait: 10.minutes)
])
```

### 4.3 Garantía de Consistencia

**Patrón Saga Choreography:**
```ruby
# 1. Invoice Service crea factura
class CreateInvoiceUseCase
  def execute(invoice_params)
    # Validar cliente existe
    customer = CustomerServiceClient.find_customer(invoice_params[:customer_id])
    return failure("Cliente no encontrado") unless customer
    
    # Crear factura
    invoice = Invoice.create!(invoice_params)
    
    # Publicar evento
    EventPublisher.publish('invoice_created', invoice.to_audit_payload)
    
    success(invoice)
  end
end
```

**Compensación en caso de fallos:**
```ruby
class CompensateInvoiceCreation
  def execute(invoice_id)
    invoice = Invoice.find(invoice_id)
    invoice.update!(status: :cancelled, cancelled_at: Time.current)
    EventPublisher.publish('invoice_cancelled', invoice.to_audit_payload)
  end
end
```

---

## 5. Estrategia de Persistencia

### 5.1 Oracle Database (Transaccional)
**Servicios:** Customer Service, Invoice Service

```ruby
# config/database.yml para servicios transaccionales
production:
  adapter: oracle_enhanced
  database: <%= ENV['ORACLE_DATABASE'] %>
  username: <%= ENV['ORACLE_USERNAME'] %>
  password: <%= ENV['ORACLE_PASSWORD'] %>
  host: <%= ENV['ORACLE_HOST'] %>
  port: 1521
```

**Entidades en Oracle:**
- `customers` - Datos maestros de clientes
- `invoices` - Facturas y líneas de detalle
- `tax_configurations` - Configuraciones tributarias

### 5.2 MongoDB (NoSQL - Auditoría)
**Servicio:** Audit Service

```ruby
# config/mongoid.yml
production:
  clients:
    default:
      uri: <%= ENV['MONGODB_URI'] %>
      options:
        max_pool_size: 20
        wait_queue_timeout: 5
```

**Documentos en MongoDB:**
- `audit_events` - Eventos de sistema
- `user_sessions` - Logs de sesiones
- `performance_metrics` - Métricas del sistema

---

## 6. Aplicación de Principios Arquitectónicos

### 6.1 Principios de Microservicios

#### Independencia y Despliegue Autónomo
```dockerfile
# Dockerfile por servicio
FROM ruby:3.2-alpine
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
CMD ["rails", "server", "-b", "0.0.0.0"]
```

#### Escalabilidad Independiente
```yaml
# docker-compose.yml
version: '3.8'
services:
  customer-service:
    build: ./customer-service
    ports:
      - "3001:3000"
    deploy:
      replicas: 2
  
  invoice-service:
    build: ./invoice-service
    ports:
      - "3002:3000"
    deploy:
      replicas: 3  # Más instancias para el core del negocio
```

### 6.2 Clean Architecture

#### Estructura de Capas por Servicio
```
invoice-service/
├── app/
│   ├── controllers/          # Infrastructure Layer
│   ├── models/              # Infrastructure Layer (ActiveRecord)
│   ├── services/            # Application Layer
│   ├── entities/            # Domain Layer
│   ├── repositories/        # Infrastructure Layer
│   └── use_cases/          # Application Layer
├── lib/
│   └── domain/             # Pure Domain Logic
└── spec/                   # Tests
```

#### Implementación de Capas
```ruby
# Domain Layer - Entidad pura
module Domain
  class Invoice
    attr_reader :id, :customer_id, :items, :status
    
    def initialize(attributes)
      @id = attributes[:id]
      @customer_id = attributes[:customer_id]
      @items = attributes[:items] || []
      @status = attributes[:status] || :draft
    end
    
    def calculate_total
      items.sum { |item| item.quantity * item.unit_price }
    end
    
    def can_be_cancelled?
      [:draft, :issued].include?(status)
    end
  end
end

# Application Layer - Caso de uso
class CreateInvoiceUseCase
  def initialize(invoice_repository, customer_repository, event_publisher)
    @invoice_repository = invoice_repository
    @customer_repository = customer_repository
    @event_publisher = event_publisher
  end
  
  def execute(invoice_data)
    # Validar cliente existe
    customer = @customer_repository.find(invoice_data[:customer_id])
    return failure("Cliente no encontrado") unless customer
    
    # Crear entidad de dominio
    invoice = Domain::Invoice.new(invoice_data)
    
    # Validar reglas de negocio
    return failure("Total inválido") if invoice.calculate_total <= 0
    
    # Persistir
    saved_invoice = @invoice_repository.save(invoice)
    
    # Publicar evento
    @event_publisher.publish('invoice_created', saved_invoice.to_h)
    
    success(saved_invoice)
  end
end

# Infrastructure Layer - Repository
class InvoiceRepository
  def save(domain_invoice)
    invoice_record = InvoiceRecord.create!(
      customer_id: domain_invoice.customer_id,
      total_amount: domain_invoice.calculate_total,
      status: domain_invoice.status
    )
    
    # Convertir de ActiveRecord a entidad de dominio
    Domain::Invoice.new(invoice_record.attributes.symbolize_keys)
  end
end
```

### 6.3 Patrón MVC

#### Controllers (Capa de Presentación)
```ruby
# app/controllers/api/v1/invoices_controller.rb
class Api::V1::InvoicesController < ApplicationController
  def create
    result = create_invoice_use_case.execute(invoice_params)
    
    if result.success?
      render json: InvoiceSerializer.new(result.data), status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end
  
  private
  
  def create_invoice_use_case
    @create_invoice_use_case ||= CreateInvoiceUseCase.new(
      InvoiceRepository.new,
      CustomerRepository.new,
      EventPublisher.new
    )
  end
  
  def invoice_params
    params.require(:invoice).permit(:customer_id, items: [:description, :quantity, :unit_price])
  end
end
```

#### Models (Representación de Datos)
```ruby
# app/models/invoice_record.rb (ActiveRecord para persistencia)
class InvoiceRecord < ApplicationRecord
  self.table_name = 'invoices'
  
  belongs_to :customer_record, foreign_key: 'customer_id'
  has_many :invoice_items
  
  validates :customer_id, presence: true
  validates :total_amount, numericality: { greater_than: 0 }
  
  enum status: { draft: 0, issued: 1, sent: 2, cancelled: 3 }
end
```

#### Views (Serialización)
```ruby
# app/serializers/invoice_serializer.rb
class InvoiceSerializer < ActiveModel::Serializer
  attributes :id, :customer_id, :total_amount, :status, :created_at
  
  has_many :items, serializer: InvoiceItemSerializer
  belongs_to :customer, serializer: CustomerBasicSerializer
end
```

---

## 7. Diagrama de Arquitectura

Para crear el diagrama de arquitectura de alto nivel, necesitarás utilizar una herramienta de diagramación. A continuación te proporciono los prompts y especificaciones necesarias:

### 7.1 Prompts para Draw.io/Lucidchart

**Prompt Principal:**
"Crear un diagrama de arquitectura de microservicios para sistema de facturación electrónica con los siguientes componentes:

1. **Capa de Presentación:**
   - Cliente Web (navegador)
   - Cliente Mobile (app)
   - API Gateway (puerto 3000)

2. **Capa de Microservicios:**
   - Customer Service (puerto 3001) - Rails API
   - Invoice Service (puerto 3002) - Rails API  
   - Audit Service (puerto 3003) - Rails API

3. **Capa de Datos:**
   - Oracle Database (para Customer y Invoice Services)
   - MongoDB (para Audit Service)

4. **Infraestructura:**
   - Redis (para caching y sesiones)
   - Sidekiq (para jobs asíncronos)
   - Message Queue (para eventos)

5. **Integraciones Externas:**
   - DIAN (Servicio tributario - futuro)
   - Email Service (notificaciones)

**Flujos a representar:**
- Flujo síncrono: Cliente → Gateway → Services
- Flujo asíncrono: Services → Message Queue → Audit Service
- Persistencia: Services → Databases"

### 7.2 Elementos del Diagrama

**Componentes por Capa:**

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPA DE PRESENTACIÓN                    │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Cliente Web   │  Cliente Mobile │      API Gateway       │
│   (React/Vue)   │     (React      │    (Rails/Nginx)       │
│                 │     Native)     │     Puerto: 3000       │
└─────────────────┴─────────────────┴─────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 CAPA DE MICROSERVICIOS                     │
├───────────────┬───────────────┬─────────────────────────────┤
│ Customer      │ Invoice       │ Audit                       │
│ Service       │ Service       │ Service                     │
│ (Rails API)   │ (Rails API)   │ (Rails API)                │
│ Puerto: 3001  │ Puerto: 3002  │ Puerto: 3003               │
└───────────────┴───────────────┴─────────────────────────────┘
         │               │                     ▲
         ▼               ▼                     │
┌─────────────────────────────────────────────┼─────────────────┐
│              CAPA DE DATOS                  │                 │
├─────────────────┬─────────────────┬─────────┼─────────────────┤
│ Oracle Database │ Oracle Database │ MongoDB │                 │
│ (Customers)     │ (Invoices)      │ (Audit) │                 │
└─────────────────┴─────────────────┴─────────┼─────────────────┘
                                              │
┌─────────────────────────────────────────────┼─────────────────┐
│                INFRAESTRUCTURA              │                 │
├─────────────┬─────────────┬─────────────────┼─────────────────┤
│   Redis     │   Sidekiq   │  Message Queue  │                 │
│ (Cache)     │ (Jobs)      │  (Events)       │                 │
└─────────────┴─────────────┴─────────────────┼─────────────────┘
                                              │
                              Eventos Async ──┘
```

### 7.3 Especificaciones Técnicas para el Diagrama

**Colores Sugeridos:**
- Azul: Servicios Rails
- Verde: Bases de datos
- Naranja: Infraestructura
- Gris: Clientes/Externa

**Conectores:**
- Líneas sólidas: Comunicación síncrona (HTTP/REST)
- Líneas punteadas: Comunicación asíncrona (eventos)
- Flechas bidireccionales: Consultas de datos
- Flechas unidireccionales: Flujo de eventos

**Anotaciones necesarias:**
- Protocolos de comunicación (HTTP, TCP, etc.)
- Puertos de servicios
- Tipos de bases de datos
- Patrones de integración (API Gateway, Event Sourcing)

---

## Conclusión

Esta arquitectura de microservicios con Ruby on Rails proporciona:

✅ **Escalabilidad:** Cada servicio puede escalar independientemente
✅ **Mantenibilidad:** Código organizado por dominio de negocio  
✅ **Flexibilidad:** Fácil integración de nuevas tecnologías
✅ **Trazabilidad:** Sistema de auditoría robusto
✅ **Cumplimiento:** Preparado para normativas tributarias

La implementación gradual permitirá migrar del sistema monolítico actual hacia esta arquitectura moderna, mejorando significativamente la eficiencia operacional de FactuMarket S.A.