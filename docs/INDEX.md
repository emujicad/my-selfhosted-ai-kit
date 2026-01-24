# 📚 Documentation Index

## 🎯 Recommended Reading Guide

### Getting Started (Read in this order)

1. **[README.md](../README.md)** - Project overview, installation and basic usage
2. **[PROJECT_STATUS.md](PROJECT_STATUS.md)** - ⭐ **NEW** - Current project status and pending tasks (consolidates ESTADO_PROYECTO + TODO)
3. **[ROADMAP.md](ROADMAP.md)** - ⭐ **NEW** - Detailed action plan with next recommended steps (consolidates PROXIMOS_PASOS + PROXIMOS_PASOS_DETALLADO)

### Essential Guides

#### Stack Management
- **[STACK_MANAGER_GUIDE.md](STACK_MANAGER_GUIDE.md)** - ⭐ **MASTER** - Main script for managing Docker Compose profiles
  - Simplified profile management
  - **Automatic dependency resolution between profiles**
  - Predefined presets (default, dev, production, full)
  - Integrated automatic validation
  - Available commands (start, stop, restart, status, info, logs, validate, monitor)

#### Authentication and Security
- **[KEYCLOAK_GUIDE.md](KEYCLOAK_GUIDE.md)** - ⭐ **COMPLETE** - Keycloak integration with all services (consolidates 4 files)
  - Key concepts (URLs, OAuth flows)
  - Credentials and access
  - Grafana + Keycloak ✅ (complete configuration and troubleshooting)
  - Open WebUI + Keycloak ✅ **COMPLETE** (Emulated OIDC  Environment)
  - n8n + Keycloak ⏳ (configuration ready)
  - Jenkins + Keycloak ⏳ (pending)
  - Database troubleshooting
  - Automatic fixes
  - Complete troubleshooting

#### Monitoring and Observability
- **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** - ⭐ **COMPLETE** - Monitoring with Grafana, dashboards and next steps (consolidates 2 files)
  - Monitoring services (Prometheus, Grafana, exporters)
  - Available dashboards (System, Ollama, GPU/CPU, Users/Sessions, Cost, Executive Summary)
  - Configuration and usage
  - Complete troubleshooting
  - Available metrics
  - Next steps and planned improvements (alerts, centralized logging, advanced metrics)

#### Performance Optimization
- **[OLLAMA_GUIDE.md](OLLAMA_GUIDE.md)** - ⭐ **COMPLETE** - Ollama optimization, monitoring and testing (consolidates 2 files)
  - Optimization configuration (MAX_LOADED_MODELS, NUM_THREAD, KEEP_ALIVE, SHM_SIZE)
  - Optimization monitoring dashboard
  - Testing and validation scripts
  - Troubleshooting

#### Configuration Management
- **[CONFIGURATION.md](CONFIGURATION.md)** - ⭐ **COMPLETE** - Configuration management and update strategies (consolidates 3 files)
  - Automatic .env fixing (transparent for user)
  - Dynamic environment variables (files vs env vars)
  - Update strategies (n8n and general)
  - Best practices

#### Troubleshooting
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - ⭐ **COMPLETE** - Comprehensive troubleshooting guide for all services
  - Quick diagnostics
  - Service-specific troubleshooting (Keycloak, Grafana, Ollama, PostgreSQL, n8n, Open WebUI)
  - Common problems (Docker, environment variables, network, authentication)
  - Database issues and recovery
  - Performance troubleshooting

#### Backup and Recovery
- **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)** - Complete backup and restore guide

#### Validation and Testing
- **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - ⭐ **COMPLETE** - Automatic validation, scripts and troubleshooting
  - Quick validation
  - Complete automatic validation
  - Available scripts
  - Troubleshooting

### Utilities and References

#### Diagrams
- **[DIAGRAMS_INSTRUCTIONS.md](DIAGRAMS_INSTRUCTIONS.md)** - How to generate PNG diagrams from .mmd files (English)
- **[DIAGRAMS_INSTRUCTIONS.es.md](DIAGRAMS_INSTRUCTIONS.es.md)** - Diagram instructions (Spanish)

---

## 📁 File Structure

### Main Documentation (Root)
- **README.md** - Main project documentation (English)
- **README.es.md** - Main project documentation (Spanish)

### Detailed Documentation (`docs/`)

**Essential Guides (6 consolidated files):**
- **PROJECT_STATUS.md** - ⭐ Current status + pending tasks
- **ROADMAP.md** - ⭐ Detailed action plan
- **KEYCLOAK_GUIDE.md** - ⭐ Complete Keycloak integration
- **MONITORING_GUIDE.md** - ⭐ Complete monitoring and observability
- **OLLAMA_GUIDE.md** - ⭐ Ollama optimization and testing
- **CONFIGURATION.md** - ⭐ Configuration and update management

**Specialized Guides:**
- **STACK_MANAGER_GUIDE.md** - Stack management
- **BACKUP_GUIDE.md** - Backups and restoration
- **VALIDATION_GUIDE.md** - Validation and testing
- **DIAGRAMS_INSTRUCTIONS.md** / **DIAGRAMS_INSTRUCTIONS.es.md** - Diagram generation

**Utilities:**
- **INDEX.md** - ⭐ This file - Reading guide

---

## 🔍 Quick Search by Topic

### Keycloak and Authentication
- See **[KEYCLOAK_GUIDE.md](KEYCLOAK_GUIDE.md)** - Everything consolidated here
  - Grafana configuration
  - Open WebUI configuration
  - n8n configuration
  - Jenkins configuration
  - Complete troubleshooting
  - Credentials and access
  - Database issues

### Monitoring and Dashboards
- See **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** - Everything consolidated here
  - Monitoring services
  - Available dashboards
  - Configuration and usage
  - Complete troubleshooting
  - Next steps and improvements

### Ollama Optimization
- See **[OLLAMA_GUIDE.md](OLLAMA_GUIDE.md)** - Everything consolidated here
  - Optimization configuration
  - Monitoring dashboard
  - Testing and validation
  - Troubleshooting

### Configuration Management
- See **[CONFIGURATION.md](CONFIGURATION.md)** - Everything consolidated here
  - Automatic .env fixing
  - Dynamic environment variables
  - Update strategies
  - Best practices

### Validation and Testing
- See **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - Everything consolidated here

### Backups
- See **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)**

### Stack Management
- See **[STACK_MANAGER_GUIDE.md](STACK_MANAGER_GUIDE.md)**

### Diagrams
- **[DIAGRAMS_INSTRUCTIONS.md](DIAGRAMS_INSTRUCTIONS.md)**
- **[DIAGRAMS_INSTRUCTIONS.es.md](DIAGRAMS_INSTRUCTIONS.es.md)**

---

## 📋 Recommended Reading Flow

### If you're new to the project:
1. Read **[README.md](../README.md)** to understand what the project is
2. Read **[PROJECT_STATUS.md](PROJECT_STATUS.md)** to see what's done and pending
3. Read **[ROADMAP.md](ROADMAP.md)** to see the action plan
4. Consult **[INDEX.md](INDEX.md)** (this file) to find specific documentation

### If you want to configure Keycloak:
1. Read **[KEYCLOAK_GUIDE.md](KEYCLOAK_GUIDE.md)** - Everything is there
   - Key concepts
   - Step-by-step configuration
   - Complete troubleshooting
   - Database issues and automatic fixes

### If you want to optimize Ollama:
1. Read **[OLLAMA_GUIDE.md](OLLAMA_GUIDE.md)** - Everything is there
   - Optimization configuration
   - Monitoring
   - Testing

### If you want to use monitoring and dashboards:
1. Read **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** - Everything is there
   - Monitoring services
   - Available dashboards
   - Configuration and usage
   - Complete troubleshooting
   - Next steps and improvements

### If you want to manage configuration:
1. Read **[CONFIGURATION.md](CONFIGURATION.md)** - Everything is there
   - Automatic .env fixing
   - Dynamic environment variables
   - Update strategies

### If you want to validate changes:
1. Read **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - Everything is there

### If you want to make backups:
1. Read **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)**

### If you want to manage the stack:
1. Read **[STACK_MANAGER_GUIDE.md](STACK_MANAGER_GUIDE.md)**

---

## 📝 Important Notes

### Consolidated Files

Information has been consolidated into 6 main files to avoid redundancy and improve organization:

**Consolidated in Phase 1-2 (2026-01-24):**

1. **ROADMAP.md** - Consolidates:
   - PROXIMOS_PASOS.md
   - PROXIMOS_PASOS_DETALLADO.md

2. **KEYCLOAK_GUIDE.md** - Consolidates:
   - KEYCLOAK_INTEGRATION_PLAN.md
   - KEYCLOAK_DB_TROUBLESHOOTING.md
   - KEYCLOAK_AUTO_FIX.md
   - KEYCLOAK_ORPHANED_CONNECTIONS.md

3. **PROJECT_STATUS.md** - Consolidates:
   - ESTADO_PROYECTO.md
   - TODO.md

4. **OLLAMA_GUIDE.md** - Consolidates:
   - OLLAMA_OPTIMIZATION_MONITORING.md
   - TESTING_OLLAMA_OPTIMIZATIONS.md

5. **MONITORING_GUIDE.md** - Consolidates:
   - GRAFANA_MONITORING_GUIDE.md
   - MONITORING_NEXT_STEPS.md

6. **CONFIGURATION.md** - Consolidates:
   - ENV_AUTO_FIX.md
   - VARIABLES_ENTORNO_DINAMICAS.md
   - N8N_UPDATE_STRATEGY.md

**Total: 16 files consolidated into 6 comprehensive guides with ZERO information loss.**

### Documentation Policy

- ✅ Consolidate related information in main files
- ✅ Create new files only when absolutely necessary
- ✅ Keep this INDEX.md updated
- ✅ One file per main topic
- ✅ README.md and README.es.md synchronized
- ❌ Don't create very specific or temporary .md files

### Files by Category

**General Documentation:**
- README.md / README.es.md
- docs/PROJECT_STATUS.md - ⭐ Status + pending tasks
- docs/ROADMAP.md - ⭐ Action plan

**Configuration:**
- docs/KEYCLOAK_GUIDE.md - ⭐ All Keycloak
- docs/CONFIGURATION.md - ⭐ Configuration management
- docs/BACKUP_GUIDE.md
- docs/STACK_MANAGER_GUIDE.md

**Monitoring:**
- docs/MONITORING_GUIDE.md - ⭐ Monitoring and observability
- docs/OLLAMA_GUIDE.md - ⭐ Ollama optimization

**Validation and Testing:**
- docs/VALIDATION_GUIDE.md

**Troubleshooting:**
- docs/TROUBLESHOOTING.md - ⭐ Complete troubleshooting guide (includes automatic fixes and Docker Compose commands)

**Utilities:**
- docs/DIAGRAMS_INSTRUCTIONS.md / docs/DIAGRAMS_INSTRUCTIONS.es.md

---

**Last updated**: 2026-01-24

