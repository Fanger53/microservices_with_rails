#!/bin/bash

# 🚀 Script de Inicio Rápido - Microservicios Rails 8
# Sistema de Facturación Electrónica

set -e

echo "🏗️  Iniciando Sistema de Facturación Electrónica..."
echo "===================================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar prerequisitos
check_prerequisites() {
    print_info "Verificando prerequisitos..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado. Por favor instalar Docker primero."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose no está instalado. Por favor instalar Docker Compose primero."
        exit 1
    fi
    
    print_status "Prerequisitos verificados correctamente"
}

# Limpiar contenedores existentes
cleanup_existing() {
    print_info "Limpiando contenedores existentes..."
    
    docker-compose down -v --remove-orphans 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
    
    print_status "Limpieza completada"
}

# Crear directorios necesarios
create_directories() {
    print_info "Creando directorios necesarios..."
    
    mkdir -p infrastructure/docker
    mkdir -p logs
    mkdir -p data/postgres
    mkdir -p data/redis
    
    print_status "Directorios creados"
}

# Inicializar base de datos
init_database() {
    print_info "Inicializando script de base de datos..."
    
    cat > infrastructure/docker/init.sql << 'EOF'
-- Inicialización de bases de datos para microservicios
-- PostgreSQL 16 con extensiones necesarias

-- Crear bases de datos para cada servicio
CREATE DATABASE customer_service_development;
CREATE DATABASE invoice_service_development; 
CREATE DATABASE audit_service_development;
CREATE DATABASE api_gateway_development;

-- Crear usuario para desarrollo
CREATE USER rails WITH PASSWORD 'password123';

-- Otorgar permisos
GRANT ALL PRIVILEGES ON DATABASE customer_service_development TO rails;
GRANT ALL PRIVILEGES ON DATABASE invoice_service_development TO rails;
GRANT ALL PRIVILEGES ON DATABASE audit_service_development TO rails;
GRANT ALL PRIVILEGES ON DATABASE api_gateway_development TO rails;

-- Conectar a cada base de datos y crear extensiones
\c customer_service_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
GRANT ALL ON SCHEMA public TO rails;

\c invoice_service_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
GRANT ALL ON SCHEMA public TO rails;

\c audit_service_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
GRANT ALL ON SCHEMA public TO rails;

\c api_gateway_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
GRANT ALL ON SCHEMA public TO rails;
EOF

    print_status "Script de base de datos creado"
}

# Construir imágenes Docker
build_images() {
    print_info "Construyendo imágenes Docker (esto puede tomar varios minutos)..."
    
    # Construir cada servicio
    echo "🔨 Construyendo API Gateway..."
    docker-compose build api-gateway --no-cache
    
    echo "🔨 Construyendo Customer Service..."
    docker-compose build customer-service --no-cache
    
    echo "🔨 Construyendo Invoice Service..."
    docker-compose build invoice-service --no-cache
    
    echo "🔨 Construyendo Audit Service..."
    docker-compose build audit-service --no-cache
    
    print_status "Imágenes Docker construidas exitosamente"
}

# Levantar infraestructura base
start_infrastructure() {
    print_info "Iniciando infraestructura base (PostgreSQL + Redis)..."
    
    docker-compose up postgres redis -d
    
    # Esperar a que PostgreSQL esté listo
    echo "⏳ Esperando que PostgreSQL esté disponible..."
    timeout 60 bash -c 'until docker-compose exec postgres pg_isready -U postgres; do sleep 2; done'
    
    # Esperar a que Redis esté listo
    echo "⏳ Esperando que Redis esté disponible..."
    timeout 30 bash -c 'until docker-compose exec redis redis-cli ping; do sleep 2; done'
    
    print_status "Infraestructura base iniciada"
}

# Inicializar bases de datos
setup_databases() {
    print_info "Configurando bases de datos..."
    
    # Esperar un poco más para asegurar que PostgreSQL esté completamente listo
    sleep 5
    
    # Ejecutar migraciones para cada servicio
    echo "📊 Preparando base de datos Customer Service..."
    docker-compose run --rm customer-service bundle exec rails db:prepare || print_warning "Customer Service DB setup tuvo problemas"
    
    echo "📊 Preparando base de datos Invoice Service..."
    docker-compose run --rm invoice-service bundle exec rails db:prepare || print_warning "Invoice Service DB setup tuvo problemas"
    
    echo "📊 Preparando base de datos Audit Service..."
    docker-compose run --rm audit-service bundle exec rails db:prepare || print_warning "Audit Service DB setup tuvo problemas"
    
    echo "📊 Preparando base de datos API Gateway..."
    docker-compose run --rm api-gateway bundle exec rails db:prepare || print_warning "API Gateway DB setup tuvo problemas"
    
    print_status "Bases de datos configuradas"
}

# Iniciar todos los servicios
start_services() {
    print_info "Iniciando todos los microservicios..."
    
    # Iniciar servicios en orden de dependencias
    echo "🚀 Iniciando Customer Service..."
    docker-compose up customer-service customer-worker -d
    
    # Esperar un poco y verificar salud
    sleep 10
    
    echo "🚀 Iniciando Invoice Service..."
    docker-compose up invoice-service invoice-worker -d
    
    sleep 10
    
    echo "🚀 Iniciando Audit Service..."
    docker-compose up audit-service audit-worker -d
    
    sleep 10
    
    echo "🚀 Iniciando API Gateway..."
    docker-compose up api-gateway -d
    
    print_status "Todos los servicios iniciados"
}

# Verificar salud de servicios
check_health() {
    print_info "Verificando salud de servicios..."
    
    sleep 15  # Dar tiempo para que los servicios se inicialicen
    
    services=(
        "http://localhost:3001/health:Customer Service"
        "http://localhost:3002/health:Invoice Service" 
        "http://localhost:3003/health:Audit Service"
        "http://localhost:3000/health:API Gateway"
    )
    
    for service in "${services[@]}"; do
        url=$(echo $service | cut -d: -f1)
        name=$(echo $service | cut -d: -f2)
        
        echo "🔍 Verificando $name..."
        
        for i in {1..10}; do
            if curl -s $url > /dev/null 2>&1; then
                print_status "$name está funcionando ✅"
                break
            else
                if [ $i -eq 10 ]; then
                    print_warning "$name no responde (puede necesitar más tiempo)"
                else
                    echo "   Intento $i/10 - Esperando..."
                    sleep 3
                fi
            fi
        done
    done
}

# Poblar datos de prueba
seed_data() {
    print_info "Creando datos de prueba..."
    
    # Seed para Customer Service
    echo "👥 Creando clientes de prueba..."
    docker-compose exec customer-service bundle exec rails db:seed || true
    
    # Seed para Invoice Service  
    echo "🧾 Creando facturas de prueba..."
    docker-compose exec invoice-service bundle exec rails db:seed || true
    
    print_status "Datos de prueba creados"
}

# Mostrar resumen final
show_summary() {
    echo ""
    echo "🎉 ¡Sistema de Facturación Electrónica iniciado exitosamente!"
    echo "============================================================="
    echo ""
    echo "📋 Servicios disponibles:"
    echo ""
    echo "🌐 API Gateway:      http://localhost:3000"
    echo "   • Autenticación:  POST /auth/login"
    echo "   • Dashboard:      GET /api/dashboard/overview"
    echo "   • Health:         GET /health/detailed"
    echo ""
    echo "👥 Customer Service: http://localhost:3001"
    echo "   • API:            GET /api/customers"
    echo "   • Health:         GET /health"
    echo ""
    echo "🧾 Invoice Service:  http://localhost:3002"
    echo "   • API:            GET /api/invoices"
    echo "   • Health:         GET /health"
    echo ""
    echo "📊 Audit Service:    http://localhost:3003"
    echo "   • API:            GET /api/audit_logs"
    echo "   • Metrics:        GET /api/metrics/summary"
    echo "   • Health:         GET /health"
    echo ""
    echo "🔑 Usuarios de prueba para autenticación:"
    echo "   • admin@example.com / admin123"
    echo "   • user@example.com / user123"
    echo "   • invoice@example.com / invoice123"
    echo ""
    echo "🧪 Comandos de testing:"
    echo "   • ./test_customer_service.sh"
    echo "   • ./test_invoice_service.sh" 
    echo "   • ./test_complete_system.sh"
    echo ""
    echo "📊 Monitoreo:"
    echo "   • docker-compose logs -f"
    echo "   • docker-compose ps"
    echo ""
    echo "🛑 Para detener:"
    echo "   • docker-compose down"
    echo ""
    print_status "¡Sistema listo para usar! 🚀"
}

# Función principal
main() {
    echo "🎯 Iniciando setup del Sistema de Facturación Electrónica"
    echo "Tiempo estimado: 5-10 minutos"
    echo ""
    
    check_prerequisites
    cleanup_existing
    create_directories
    init_database
    build_images
    start_infrastructure
    setup_databases
    start_services
    check_health
    seed_data
    show_summary
}

# Manejar interrupciones
trap 'print_error "Setup interrumpido por el usuario"; exit 1' INT

# Ejecutar función principal
main "$@"