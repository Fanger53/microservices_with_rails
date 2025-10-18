-- Crear databases adicionales si son necesarios
CREATE DATABASE customer_service_test;
CREATE DATABASE customer_service_jobs;

-- Crear extensiones necesarias
\c customer_service_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c customer_service_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c customer_service_jobs;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
