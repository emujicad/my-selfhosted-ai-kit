#!/bin/bash
# scripts/validate-system.sh

# =============================================================================
# MY SELF-HOSTED AI KIT - Unified Validation System
# =============================================================================
# Master script for all validation tasks:
# - Environment Variables (--env)
# - Stack Configuration (--config)
# - Ollama Models (--models)
# =============================================================================

set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Global counters
ERRORS=0
WARNINGS=0

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ERRORS=$((ERRORS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# =============================================================================
# Logic: Environment Variables (--env)
# =============================================================================

check_env() {
    print_header "VALIDATING ENVIRONMENT VARIABLES"

    if [ ! -f "${PROJECT_DIR}/.env" ]; then
        print_error ".env file not found"
        return 1
    fi

    # Load .env safely
    set -a
    source "${PROJECT_DIR}/.env" 2>/dev/null
    set +a

    # Critical variables list
    local CRITICAL_VARS=(
        "REDIS_HOST" "REDIS_PORT"
        "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB"
        "OLLAMA_HOST_INTERNAL" "OLLAMA_PORT_INTERNAL"
        "OPEN_WEBUI_URL_PUBLIC"
        "KEYCLOAK_ADMIN_USER" "KEYCLOAK_ADMIN_PASSWORD"
    )

    for VAR in "${CRITICAL_VARS[@]}"; do
        local VALUE="${!VAR:-}"
        
        if [ -z "$VALUE" ]; then
            print_error "$VAR is empty or undefined"
        elif [[ "$VALUE" == *"change_me"* ]] || [[ "$VALUE" == *"your-"* ]]; then
            if [[ "$VAR" == *"PASSWORD"* ]] || [[ "$VAR" == *"SECRET"* ]]; then
                 print_warning "$VAR seems to use a placeholder value"
            fi
        fi
    done

    # Verify constructed URLs (check logic)
    if [ -z "${OLLAMA_URL_INTERNAL:-}" ]; then
        if [ -n "${OLLAMA_HOST_INTERNAL:-}" ] && [ -n "${OLLAMA_PORT_INTERNAL:-}" ]; then
            print_info "OLLAMA_URL_INTERNAL undefined but constructible (OK)"
        else
            print_error "OLLAMA_URL_INTERNAL undefined and cannot be constructed"
        fi
    fi
}

# =============================================================================
# Main Execution Logic
# =============================================================================

show_help() {
    echo "Usage: ./validate-system.sh [FLAGS]"
    echo ""
    echo "Flags:"
    echo "  --env       Validate environment variables"
    echo "  --config    Validate configuration files"
    echo "  --models        Validate/Monitor Ollama models"
    echo "  --deploy-check  Start stack and verify runtime status"
    echo "  --all           Run all validations (default)"
    echo "  --help          Show this help"
    echo ""
}

# Default behavior
RUN_ENV=false
RUN_CONFIG=false
RUN_MODELS=false
RUN_DEPLOY=false

# Parse arguments
if [ $# -eq 0 ]; then
    RUN_ENV=true
    RUN_CONFIG=true
    RUN_MODELS=true
    # Default NO deploy check to ensure safety, unless explicitly requested or --all
    # Actually, let's keep --all as PASSIVE checks only for safety?
    # User asked for TOTAL unification. Let's make --all include deployment?
    # No, --all usually implies "Validate everything current".
    # Let's keep deploy as opt-in via flag or specific --deploy-check
    # But wait, auto-validate did EVERYTHING.
    # Let's stick to explicit flag for deploy actions.
else
    for arg in "$@"; do
        case $arg in
            --env) RUN_ENV=true ;;
            --config) RUN_CONFIG=true ;;
            --models) RUN_MODELS=true ;;
            --deploy-check) RUN_DEPLOY=true ;;
            --all) 
                RUN_ENV=true
                RUN_CONFIG=true
                RUN_MODELS=true
                # RUN_DEPLOY=true # Uncomment if we want --all to start containers (Risky?)
                ;;
            --help) 
                show_help
                exit 0 
                ;;
            *) 
                echo -e "${RED}Unknown argument: $arg${NC}"
                show_help
                exit 1 
                ;;
        esac
    done
fi

# Execute requested checks
if [ "$RUN_ENV" = true ]; then check_env; fi
# =============================================================================
# Logic: Stack Configuration (--config)
# =============================================================================

check_config() {
    print_header "VALIDATING STACK CONFIGURATION"
    
    # Helper functions local to check_config
    local_check_file() {
        if [ -f "${PROJECT_DIR}/$1" ]; then
            print_success "$1 exists"
        else
            print_error "$1 NOT found"
        fi
    }
    
    local_check_dir() {
        if [ -d "${PROJECT_DIR}/$1" ]; then
            print_success "$1/ exists"
        else
            print_error "$1/ NOT found"
        fi
    }
    
    local_check_content() {
        if grep -q "$2" "${PROJECT_DIR}/$1" 2>/dev/null; then
            print_success "$1 contains: $2"
        else
            print_error "$1 does NOT contain: $2"
        fi
    }

    # 1. ModSecurity
    echo "--- ModSecurity ---"
    local_check_file "modsecurity/modsecurity.conf"
    local_check_dir "modsecurity/rules"
    
    # 2. Prometheus
    echo "--- Prometheus ---"
    local_check_file "monitoring/prometheus.yml"
    local_check_file "monitoring/prometheus/alerts.yml"
    
    # 3. Docker Compose
    echo "--- Docker Compose ---"
    local_check_file "docker-compose.yml"
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local_check_content "docker-compose.yml" "modsecurity.conf"
        local_check_content "docker-compose.yml" "alerts.yml"
    fi
    
    echo "--- YAML Syntax Check ---"
    if command -v python3 > /dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('${PROJECT_DIR}/monitoring/prometheus.yml'))" 2>/dev/null; then
             print_success "prometheus.yml syntax valid"
        else
             print_error "prometheus.yml syntax INVALID"
        fi
    else
        print_info "Python3 not found - Skipping detailed YAML syntax check"
    fi
}

# =============================================================================
# Logic: Ollama Models (--models)
# =============================================================================

check_models() {
    print_header "VALIDATING OLLAMA MODELS"

    # Check if Docker is available
    if ! command -v docker > /dev/null 2>&1 && ! command -v sudo > /dev/null 2>&1; then
        print_error "Docker not found"
        return 1
    fi
    
    local DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi

    # Check if Ollama container is strictly running
    # We use format {{.State.Running}} to get true/false
    local OLLAMA_STATUS=$($DOCKER_CMD inspect -f '{{.State.Running}}' ollama 2>/dev/null || echo "false")

    if [ "$OLLAMA_STATUS" != "true" ]; then
        print_warning "Ollama container is NOT running (Status: $OLLAMA_STATUS). Skipping model list."
        # This is not a validation error, just a runtime state. We don't increment ERRORS.
        return 0
    fi

    print_info "Ollama is running. Listing available models:"
    echo ""
    
    if $DOCKER_CMD exec ollama ollama list; then
        print_success "Model list retrieved successfully"
    else
        print_error "Failed to retrieve model list (Command execution failed)"
    fi
    
    # Check for download process
    if $DOCKER_CMD ps | grep -q "ollama-pull"; then
        print_info "A model download seems to be in progress (ollama-pull-* container active)"
        echo "   To monitor download, use: ./scripts/stack-manager.sh monitor"
    fi
}

# =============================================================================
# Logic: Deploy Check (--deploy-check)
# =============================================================================

check_deploy() {
    print_header "DEPLOYMENT CHECK & ORCHESTRATION"
    
    # Check if Docker is available
    if ! command -v docker > /dev/null 2>&1 && ! command -v sudo > /dev/null 2>&1; then
        print_error "Docker not found - Cannot run deployment check"
        return 1
    fi
    local DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi

    # 1. Start Services (Orchestration)
    print_info "Starting core services..."
    if ! $DOCKER_CMD compose up -d postgres pgvector qdrant 2>&1; then
        print_error "Failed to start core services"
        return 1
    fi
    print_success "Core services checked/started"
    
    print_info "Starting monitoring services..."
    if ! $DOCKER_CMD compose --profile monitoring up -d prometheus grafana alertmanager 2>&1; then
        print_error "Failed to start monitoring services"
    else
        print_success "Monitoring services checked/started"
    fi
    
    print_info "Starting security services..."
    if ! $DOCKER_CMD compose --profile security up -d modsecurity 2>&1; then
        print_error "Failed to start security services"
    else
        print_success "Security services checked/started"
    fi
    
    print_info "Waiting for services to settle (10s)..."
    sleep 10
    
    # 2. Verify Runtime Status
    print_header "VERIFYING RUNTIME STATUS"
    
    # Verify Prometheus
    if $DOCKER_CMD compose --profile monitoring ps prometheus | grep -q "Up\|running"; then
        print_success "Prometheus container is running"
        sleep 2
        if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
            print_success "Prometheus endpoint healthy (http://localhost:9090)"
        else
             print_warning "Prometheus running but endpoint check failed (might imply starting up)"
        fi
    else
        print_error "Prometheus container NOT running"
    fi
    
    # Verify Logs (Sample)
    print_info "Checking Prometheus logs for critical errors..."
    if $DOCKER_CMD compose --profile monitoring logs --tail=20 prometheus 2>&1 | grep -qi "fatal\|panic"; then
         print_warning "Potential critical errors found in Prometheus logs"
    else
         print_success "No fatal errors in recent Prometheus logs"
    fi
}

if [ "$RUN_CONFIG" = true ]; then check_config; fi
if [ "$RUN_MODELS" = true ]; then check_models; fi
if [ "$RUN_DEPLOY" = true ]; then check_deploy; fi

# Final Report
echo ""
echo "============================================="
echo "SUMMARY:"
echo "============================================="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}PASSED WITH WARNINGS${NC}"
    else
        echo -e "${GREEN}PASSED${NC}"
    fi
    exit 0
else
    echo -e "${RED}FAILED${NC}"
    exit 1
fi
