#!/bin/bash
# scripts/verify-env-variables.sh
# Verifica que todas las variables críticas de .env estén configuradas correctamente

set +e  # No salir en error para poder mostrar todos los problemas

echo "🔍 VERIFICANDO VARIABLES DE ENTORNO CRÍTICAS"
echo "============================================="
echo ""

# Cargar .env si existe
if [ -f .env ]; then
    # Usar source con set -a para auto-exportar todas las variables
    # Esto es más confiable que leer línea por línea
    set -a  # Auto-export todas las variables
    source .env 2>/dev/null || {
        echo "❌ ERROR: No se pudo cargar el archivo .env"
        exit 1
    }
    set +a  # Desactivar auto-export
else
    echo "❌ ERROR: Archivo .env no encontrado"
    exit 1
fi

# Lista de variables críticas que NO deben estar vacías
CRITICAL_VARS=(
    # Redis
    "REDIS_HOST"
    "REDIS_PORT"
    "N8N_REDIS_HOST"
    "N8N_REDIS_PORT"

    # PostgreSQL
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
    "POSTGRES_DB"
    "POSTGRES_HOST_INTERNAL"
    "POSTGRES_PORT_INTERNAL"
    
    # Ollama
    "OLLAMA_HOST_INTERNAL"
    "OLLAMA_PORT_INTERNAL"
    
    # Open WebUI
    "OPEN_WEBUI_URL_PUBLIC"
    
    # n8n
    "N8N_DB_TYPE"
    "N8N_DB_HOST"
    "N8N_ENCRYPTION_KEY"
    "N8N_USER_MANAGEMENT_JWT_SECRET"
    
    # Keycloak
    "KEYCLOAK_ADMIN_USER"
    "KEYCLOAK_ADMIN_PASSWORD"
    "KEYCLOAK_DB_TYPE"
    "KEYCLOAK_DB_NAME"
    "KEYCLOAK_HOST_INTERNAL"
    "KEYCLOAK_REALM"
    "KEYCLOAK_URL_PUBLIC"
    "KEYCLOAK_URL_INTERNAL"
    
    # Grafana
    "GRAFANA_ADMIN_PASSWORD"
    "GRAFANA_URL_PUBLIC"
    
    # URLs construidas que dependen de otras variables
    "HOSTNAME_PUBLIC"
)

ERRORS=0
WARNINGS=0

echo "Verificando variables críticas..."
echo ""

for VAR in "${CRITICAL_VARS[@]}"; do
    VALUE="${!VAR}"
    
    if [ -z "$VALUE" ]; then
        echo "❌ ERROR: $VAR está vacía o no definida"
        ERRORS=$((ERRORS + 1))
    elif [[ "$VALUE" == *"change_me"* ]] || [[ "$VALUE" == *"your-"* ]] || [[ "$VALUE" == *"localhost"* && "$VAR" != *"PUBLIC"* && "$VAR" != *"URL_PUBLIC"* ]]; then
        # Algunos valores por defecto son aceptables, pero verificamos casos problemáticos
        if [[ "$VAR" == *"PASSWORD"* ]] || [[ "$VAR" == *"SECRET"* ]] || [[ "$VAR" == *"KEY"* ]]; then
            if [[ "$VALUE" == *"change_me"* ]] || [[ "$VALUE" == *"your-"* ]]; then
                echo "⚠️  WARNING: $VAR parece tener un valor placeholder: ${VALUE:0:20}..."
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi
done

# Verificar URLs construidas que podrían estar vacías
echo ""
echo "Verificando URLs construidas y variables que podrían causar problemas..."
echo ""

# Función para verificar si una variable está definida pero vacía en .env
check_empty_var() {
    local var_name=$1
    local var_value="${!var_name}"
    
    # Verificar si la variable está en .env pero vacía
    if grep -q "^[[:space:]]*${var_name}=[[:space:]]*$" .env 2>/dev/null; then
        echo "❌ ERROR: $var_name está definida pero VACÍA en .env"
        echo "   Solución: Darle un valor o eliminar/comentar la línea"
        return 1
    elif [ -z "$var_value" ] && grep -q "^[[:space:]]*${var_name}=" .env 2>/dev/null; then
        echo "❌ ERROR: $var_name está definida pero VACÍA en .env"
        echo "   Solución: Darle un valor o eliminar/comentar la línea"
        return 1
    fi
    return 0
}

# Verificar variables críticas que construyen URLs
URL_VARS=(
    "OLLAMA_URL_INTERNAL"
    "OLLAMA_HOST_INTERNAL"
    "OLLAMA_PORT_INTERNAL"
    "KEYCLOAK_URL_INTERNAL"
    "KEYCLOAK_URL_PUBLIC"
    "KEYCLOAK_HOST_INTERNAL"
    "POSTGRES_URL_INTERNAL"
    "POSTGRES_HOST_INTERNAL"
    "POSTGRES_PORT_INTERNAL"
)

for VAR in "${URL_VARS[@]}"; do
    if ! check_empty_var "$VAR"; then
        ERRORS=$((ERRORS + 1))
    fi
done

# Verificar OLLAMA_URL_INTERNAL específicamente
if [ -z "$OLLAMA_URL_INTERNAL" ]; then
    if [ -n "$OLLAMA_HOST_INTERNAL" ] && [ -n "$OLLAMA_PORT_INTERNAL" ]; then
        echo "ℹ️  INFO: OLLAMA_URL_INTERNAL no está definida, pero se puede construir desde OLLAMA_HOST_INTERNAL y OLLAMA_PORT_INTERNAL"
    else
        if grep -q "^[[:space:]]*OLLAMA_URL_INTERNAL=" .env 2>/dev/null; then
            echo "❌ ERROR: OLLAMA_URL_INTERNAL está vacía en .env y no se puede construir"
            ERRORS=$((ERRORS + 1))
        fi
    fi
fi

# Verificar KEYCLOAK_URL_INTERNAL
if [ -z "$KEYCLOAK_URL_INTERNAL" ]; then
    if grep -q "^[[:space:]]*KEYCLOAK_URL_INTERNAL=" .env 2>/dev/null; then
        echo "⚠️  WARNING: KEYCLOAK_URL_INTERNAL está vacía en .env"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Resumen
echo ""
echo "============================================="
echo "RESUMEN:"
echo "============================================="
echo "Errores encontrados: $ERRORS"
echo "Advertencias: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Todas las variables críticas están configuradas correctamente"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Hay algunas advertencias, pero no hay errores críticos"
    exit 0
else
    echo "❌ Se encontraron errores críticos. Por favor, corrige las variables vacías en .env"
    exit 1
fi

