# Prompts para Crear Diagramas de Arquitectura
## Sistema de Facturación Electrónica - FactuMarket S.A.

### Herramientas Recomendadas:
- **Draw.io** (gratuito, online)
- **Lucidchart** (profesional)
- **Figma** (colaborativo)
- **Miro** (interactivo)

---

## Prompt 1: Diagrama de Alto Nivel

### Para Draw.io:
```
Título: "Arquitectura de Microservicios - Sistema de Facturación Electrónica"

Crear diagrama con las siguientes secciones verticales:

SECCIÓN 1 - CLIENTES (Superior):
- Rectángulo "Cliente Web Browser" [Color: #E3F2FD]
- Rectángulo "Aplicación Mobile" [Color: #E3F2FD] 
- Ambos conectados con flechas hacia abajo a "API Gateway"

SECCIÓN 2 - API GATEWAY (Centro-Superior):
- Rectángulo "API Gateway (Rails)" [Color: #FFF3E0]
- Puerto: 3000
- Texto: "Balanceador de carga, Autenticación, Rate Limiting"

SECCIÓN 3 - MICROSERVICIOS (Centro):
- Rectángulo "Customer Service" [Color: #E8F5E8]
  - Puerto: 3001
  - Texto: "Gestión de Clientes, Validaciones Fiscales"
- Rectángulo "Invoice Service" [Color: #E8F5E8]  
  - Puerto: 3002
  - Texto: "Emisión Facturas, Cálculos Tributarios"
- Rectángulo "Audit Service" [Color: #E8F5E8]
  - Puerto: 3003
  - Texto: "Trazabilidad, Logs de Sistema"

SECCIÓN 4 - PERSISTENCIA (Centro-Inferior):
- Cilindro "Oracle DB (Customers)" [Color: #FFEBEE]
- Cilindro "Oracle DB (Invoices)" [Color: #FFEBEE]
- Cilindro "MongoDB (Audit)" [Color: #F3E5F5]

SECCIÓN 5 - INFRAESTRUCTURA (Inferior):
- Rectángulo "Redis Cache" [Color: #FCE4EC]
- Rectángulo "Sidekiq Jobs" [Color: #FCE4EC]
- Rectángulo "Message Queue" [Color: #FCE4EC]

SECCIÓN 6 - EXTERNOS (Lateral Derecho):
- Rectángulo "DIAN (Futuro)" [Color: #FAFAFA]
- Rectángulo "Email Service" [Color: #FAFAFA]

CONEXIONES:
- API Gateway → Microservicios: Líneas sólidas azules (HTTP/REST)
- Microservicios → Bases de Datos: Líneas sólidas verdes
- Services → Message Queue: Líneas punteadas naranjas (Async)
- Message Queue → Audit Service: Línea punteada naranja
```

---

## Prompt 2: Diagrama de Flujo de Facturación

### Para Lucidchart/Draw.io:
```
Título: "Flujo de Creación de Factura Electrónica"

FLUJO PRINCIPAL:
1. Inicio: "Usuario solicita crear factura"
2. Decisión: "¿Cliente existe?" 
   - SI → Continuar
   - NO → "Crear cliente primero" → Customer Service
3. Proceso: "Validar datos de factura" → Invoice Service
4. Proceso: "Calcular impuestos (IVA, retenciones)"
5. Proceso: "Generar número consecutivo"
6. Decisión: "¿Validaciones OK?"
   - SI → Continuar  
   - NO → "Retornar errores"
7. Proceso: "Guardar en Oracle DB"
8. Proceso: "Publicar evento 'invoice_created'"
9. Proceso paralelo: "Registrar en Audit Service" (MongoDB)
10. Proceso paralelo: "Generar PDF/XML"
11. Fin: "Factura creada exitosamente"

ACTORES:
- Usuario/Cliente
- API Gateway  
- Customer Service
- Invoice Service
- Audit Service
- Oracle Database
- MongoDB
- Message Queue

USAR SÍMBOLOS:
- Óvalos para inicio/fin
- Rectángulos para procesos
- Diamantes para decisiones
- Cilindros para bases de datos
- Líneas con flechas para flujo secuencial
- Líneas punteadas para procesos paralelos
```

---

## Prompt 3: Diagrama de Clean Architecture

### Para cualquier herramienta:
```
Título: "Clean Architecture - Invoice Service"

CREAR CÍRCULOS CONCÉNTRICOS:

CÍRCULO INTERNO (Dominio):
- Color: #4CAF50
- Entidades: Invoice, InvoiceItem, Customer
- Value Objects: Money, TaxRate, InvoiceNumber
- Business Rules: CalculateTaxes, ValidateInvoice

SEGUNDO CÍRCULO (Casos de Uso):
- Color: #2196F3
- CreateInvoice
- UpdateInvoice  
- CancelInvoice
- GenerateElectronicDocument
- SubmitToDIAN

TERCER CÍRCULO (Adaptadores):
- Color: #FF9800
- Controllers: InvoicesController
- Presenters: InvoiceSerializer
- Gateways: CustomerServiceGateway
- Repositories: InvoiceRepository

CÍRCULO EXTERNO (Frameworks):
- Color: #9C27B0
- Rails Framework
- Oracle Database
- HTTP Clients
- Job Queues
- External APIs

FLECHAS:
- Solo hacia adentro (Dependency Rule)
- Interfaces en los límites
- Anotaciones: "Las dependencias apuntan hacia el dominio"
```

---

## Prompt 4: Diagrama de Despliegue

### Para herramientas de infraestructura:
```
Título: "Arquitectura de Despliegue - Microservicios Rails"

CONTENEDORES DOCKER:
- customer-service:3001 [2 réplicas]
- invoice-service:3002 [3 réplicas] 
- audit-service:3003 [1 réplica]
- api-gateway:3000 [2 réplicas]

ORQUESTACIÓN:
- Docker Compose (desarrollo)
- Kubernetes (producción)

BASES DE DATOS:
- Oracle RAC (cluster para alta disponibilidad)
- MongoDB Replica Set (3 nodos)

INFRAESTRUCTURA:
- Load Balancer (Nginx/HAProxy)
- Redis Cluster
- Sidekiq Processes

MONITOREO:
- Logs centralizados (ELK Stack)
- Métricas (Prometheus + Grafana)
- Health Checks

SEGURIDAD:
- JWT Authentication
- HTTPS/TLS
- VPN para DB connections
- Secrets Management
```

---

## Prompt 5: Diagrama de Integración con DIAN

### Para planificar integración futura:
```
Título: "Integración con DIAN - Servicios Tributarios"

COMPONENTES:
1. Invoice Service (Interno)
2. DIAN Adapter Service (Nuevo)
3. DIAN Web Services (Externo)

FLUJO DE INTEGRACIÓN:
1. "Factura creada" → Invoice Service
2. "Transformar a formato DIAN" → DIAN Adapter  
3. "Firmar digitalmente" → Certificado Digital
4. "Enviar a DIAN" → Web Service DIAN
5. "Recibir CUFE" → Código único factura
6. "Actualizar estado" → Invoice Service
7. "Notificar cliente" → Email Service

CONSIDERACIONES:
- Certificados digitales
- Firmado XML
- Validación XSD
- Retry policies
- Circuit breaker
- Audit trail completo

TECNOLOGÍAS:
- SOAP/XML para DIAN
- Nokogiri para XML processing
- OpenSSL para firmado
- Sidekiq para procesamiento asíncrono
```

---

## Instrucciones de Uso

### Pasos para crear cada diagrama:

1. **Seleccionar herramienta** (recomendación: Draw.io por ser gratuito)
2. **Copiar el prompt correspondiente**
3. **Crear nuevo diagrama en blanco**
4. **Seguir las especificaciones de colores y formas**
5. **Añadir conectores según se indica**
6. **Validar que el diagrama sea autoexplicativo**

### Consejos de Diseño:

- **Usar colores consistentes** por tipo de componente
- **Mantener flujo de lectura** de izquierda a derecha o arriba a abajo
- **Incluir leyenda** con significado de colores y símbolos
- **Añadir notas explicativas** en componentes complejos
- **Validar escalabilidad visual** - que se entienda en tamaño pequeño

### Entregables Sugeridos:

1. **Diagrama de Alto Nivel** - Vista general del sistema
2. **Diagrama de Flujo** - Proceso de facturación  
3. **Clean Architecture** - Estructura interna de servicios
4. **Diagrama de Despliegue** - Infraestructura y escalabilidad
5. **Integración DIAN** - Planificación futura

Cada diagrama debe ser exportado en formato PNG y PDF para incluir en la documentación técnica.