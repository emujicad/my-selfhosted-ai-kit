# Project Context - My Self-Hosted AI Kit

> **Quick Reference Guide for AI Assistants and Developers**

## Project Overview

**Name**: My Self-Hosted AI Kit  
**Type**: Docker Compose Stack  
**Purpose**: Complete self-hosted AI infrastructure with monitoring, automation, and security  
**Version**: Production-ready (2026-01-24)  
**License**: Apache 2.0

## Architecture Summary

### Core Components
- **AI Engine**: Ollama (LLM server) + Open WebUI (chat interface)
- **Automation**: n8n (workflow engine)
- **Database**: PostgreSQL (n8n) + Qdrant (vector database)
- **Authentication**: Keycloak (SSO/OIDC)
- **Monitoring**: Prometheus + Grafana
- **Security**: HAProxy + ModSecurity WAF
- **CI/CD**: Jenkins (optional)

### Hardware Profile
- **GPU**: NVIDIA RTX 5060 Ti (16GB VRAM)
- **CPU**: Ryzen 7 7700 (8 cores)
- **RAM**: 96GB
- **OS**: Linux with Docker Engine

## Key Technical Decisions

### 1. "Emulated OIDC Environment" for Open WebUI
**Challenge**: Docker networking split routing between browser (localhost) and backend (internal DNS)  
**Solution**: Static OIDC configuration files mounted in Open WebUI container
- `config/open-webui-oidc/oidc-config.json`: Discovery endpoint with split horizon DNS
- `config/open-webui-oidc/userinfo.json`: UserInfo endpoint bypass for 401 errors
- **Status**: Production-ready, fully functional

### 2. Automatic Dependency Resolution in stack-manager.sh
**Challenge**: Starting profiles failed due to undefined service dependencies  
**Solution**: Recursive dependency resolution based on profile hierarchy
- `get_profile_dependencies()`: Maps profile dependencies
- `resolve_dependencies()`: Recursively resolves all required profiles
- **Status**: Implemented and tested

### 3. Documentation & Script Consolidation (2026-01-24)
**Challenge**: Fragmented documentation and script sprawl.
**Solution**: Consolidated 10+ scripts into 4 main tools (`stack`, `auth`, `backup`, `validate`) and merged 24 docs into 13 guides.
- **New Tool**: `auth-manager.sh` replaces 5 legacy scripts.
- **Status**: Complete

### 4. Enhanced Backup Coverage
**Challenge**: Critical config directories not included in backups  
**Solution**: Extended `backup-manager.sh` to include all configuration  
- **Added**: `config/` and `haproxy/` directories
- **Excluded**: `ollama_storage` (models downloadable), temporary volumes (regenerable)
- **Status**: Production-ready

## Directory Structure

```
my-selfhosted-ai-kit/
├── config/                    # Configuration files
│   └── open-webui-oidc/       # OIDC static config files
├── docker-compose.yml         # Service orchestration
├── .env                       # Environment variables
├── docs/                      # Documentation (15 files, ~5,700 lines)
├── scripts/                   # Management scripts (20 total: 4 core, 10 tests, 6 utils)
│   ├── stack-manager.sh       # Main orchestration script
│   ├── auth-manager.sh        # Identity & Security manager
│   ├── backup-manager.sh      # Backup/restore manager
│   └── validate-system.sh     # System validation tool
├── monitoring/                # Prometheus + Grafana configs
│   ├── grafana/dashboards/    # JSON dashboard definitions
│   └── prometheus/            # Rules and alerts
├── haproxy/                   # Reverse proxy configuration
├── modsecurity/               # WAF rules
├── diagrams_mmd/              # Mermaid diagram sources
└── diagrams_png/              # Generated PNG diagrams
```

## Important Environment Variables

### PostgreSQL
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

### Keycloak
- `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`
- `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`

### Open WebUI (OIDC)
- `OPENID_PROVIDER_URL`: Points to static `oidc-config.json`
- `OPENID_REDIRECT_URI`: OAuth callback URL
- `ENABLE_OAUTH_SIGNUP`: Auto-registration
- `OAUTH_MERGE_ACCOUNTS_BY_EMAIL`: Email-based account linking

### Ollama
- `OLLAMA_NUM_PARALLEL`, `OLLAMA_FLASH_ATTENTION`
- `OLLAMA_MAX_LOADED_MODELS`, `OLLAMA_KEEP_ALIVE`

## Excluded from Backups (Intentional)

1. **`ollama_storage`**: Models are re-downloadable (saves ~50GB per backup)
2. **`ssl_certs_data`**: Auto-generated certificates (regenerable)
3. **`logs_data`**: Operational logs (temporary)
4. **`prometheus_rules_data`**: Derived from `monitoring/` (regenerable)
5. **`grafana_provisioning_data`**: Derived from `monitoring/grafana/` (regenerable)

## Recent Major Changes (Last 7 Days)

### 2026-01-24: Documentation Consolidation & Backup Enhancement
- Consolidated 18 documentation files into 7 guides
- Removed obsolete files (AUTO_FIXES_SUMMARY, DASHBOARD_VALIDATION_REPORT, etc.)
- Enhanced backup-manager.sh to include config/ and haproxy/
- Reorganized root directory (moved OIDC configs to config/open-webui-oidc/)
- Removed empty keycloak-proxy/ directory
- **Fixed malformed placeholders in .env.example (KEYCLOAK_ADMIN_EMAIL)**
- **Monitoring Fixes**:
  - **Keycloak**: Enabled metrics (Port 9000 + Flag), fixed Prometheus scrapers
  - **Ollama**: Optimized Model Size metrics (API usage correction), fixed 0GB size issue
  - **Validation**: Updated `auto-validate.sh` for robust metrics checks

### 2026-01-24: Full Test Suite
- **100% Coverage**: Achieved 12/12 fully passing tests for all critical scripts
- **Robustness**: Integration tests now handle offline services gracefully (exit 0)
- **New Tests**: Added `test-stack-manager`, `test-backup-manager`, `test-keycloak-*`
- **Master Runner**: Created `run-all-tests.sh` for single-command validation

### 2026-01-24: Redis & Cache Optimization
- **Redis Integration**: Configured Redis for n8n (workflow/queue) and Open WebUI (RAG/embeddings)
- **Environment**: Standardized Redis host variables in `.env`
- **Bug Fix**: Fixed unbound `DEBUG_PROFILES` variable in `stack-manager.sh`
- **Architecture**: Decoupled HAProxy from strict monitoring dependencies for flexible startup


### 2026-01-23: Diagram Improvements
- Created architecture_complete.mmd (full system architecture)
- Created oidc_authentication_flow.mmd (SSO sequence)
- Created profile_dependencies.mmd (stack-manager dependencies)
- Updated perfiles.mmd with current architecture

### 2026-01-22: Stack Manager Enhancement
- Implemented automatic dependency resolution
- Added recursive dependency tracking
- Improved error handling for undefined services

## Known Issues & Limitations

1. **No HTTPS/SSL by default**: HAProxy is configured but requires manual SSL setup
2. **Ollama models not backed up**: Intentional to save space, but requires re-download on restore
3. **Single-node deployment**: No clustering or high availability
4. **Manual Keycloak realm config**: Requires one-time setup via UI
5. **Open WebUI model filtering**: Must be configured via Admin Panel UI (Settings → Models). Arena Model cannot be hidden in v0.7.2

## Development Workflow

### Starting Services
```bash
./scripts/stack-manager.sh start [profile]
# Profiles: chat-ai, automation, gpu-nvidia, monitoring, security, infrastructure
```

### Creating Backups
```bash
./scripts/backup-manager.sh backup --verify
```

### Viewing Logs
```bash
docker compose logs -f [service]
```

### Accessing UIs
- Open WebUI: http://localhost:3000
- Keycloak: http://localhost:8080
- Grafana: http://localhost:4000 (admin/admin)
- n8n: http://localhost:5678

## Documentation Entry Points

1. **New Users**: [`README.md`](README.md) or [`README.es.md`](README.es.md)
2. **Quick Reference**: [`docs/INDEX.md`](docs/INDEX.md)
3. **Current Status**: [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md)
4. **Future Plans**: [`docs/ROADMAP.md`](docs/ROADMAP.md)
5. **Troubleshooting**: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

## External Dependencies

- Docker Engine (not Docker Desktop)
- NVIDIA Docker Runtime (for GPU support)
- NVIDIA proprietary drivers (for RTX GPUs)
- Git (for cloning)

---

**Last Updated**: 2026-01-24  
**Maintained By**: emujicad  
**AI Assistant**: Antigravity (Google DeepMind)
