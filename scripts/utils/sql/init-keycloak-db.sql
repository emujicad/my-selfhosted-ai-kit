-- Script de inicialización de base de datos para Keycloak
-- Este script crea la base de datos keycloak si no existe

-- Crear base de datos keycloak si no existe
SELECT 'CREATE DATABASE keycloak'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec

-- Conectar a la base de datos keycloak
\c keycloak;

-- Crear extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Comentario sobre la configuración
-- Keycloak creará automáticamente todas las tablas necesarias
-- cuando se inicie por primera vez 