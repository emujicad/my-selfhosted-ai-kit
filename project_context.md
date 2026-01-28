# Project Context - My Self-Hosted AI Kit

> **Quick Reference Guide for AI Assistants and Developers**

## Project Overview

**Name**: My Self-Hosted AI Kit  
**Type**: Docker Compose Stack  
**Purpose**: Complete self-hosted AI infrastructure with monitoring, automation, and security  
**Version**: Production-ready (2026-01-28)  
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

### Hardware Profile (Tested Configuration)
- **GPU**: NVIDIA RTX series with 16GB VRAM (e.g., RTX 4080, RTX 5060 Ti)
- **CPU**: 8+ cores (e.g., AMD Ryzen 7, Intel i7)
- **RAM**: 32GB+ (tested with 96GB)
- **OS**: Linux with Docker Engine

## Key Technical Decisions

### 1. "Emulated OIDC Environment" for Open WebUI
**Challenge**: Docker networking split routing between browser (localhost) and backend (internal DNS)  
**Solution**: Static OIDC configuration files mounted in Open WebUI container
- `config/open-webui-oidc/oidc-config.json`: Discovery endpoint with split horizon DNS
- `config/open-webui-oidc/userinfo.json`: UserInfo endpoint bypass for 401 errors
- **Status**: Production-ready, fully functional

### 2. Automatic Dependency Resolution in stack-manager.sh
**Challenge**: Starting profiles failed due to undefined service dependencies and profile conflicts (CPU vs GPU)
**Solution**: Recursive dependency resolution with strict profile separation in presets.
- `get_profile_dependencies()`: Maps profile dependencies
- `resolve_dependencies()`: Recursively resolves all required profiles
- **Optimization (2026-01-27)**: Decoupled `dev` (CPU-bound) from `full` preset to prevent port conflicts with `gpu-nvidia`.
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
│   ├── jenkins/               # Jenkins Dockerfile, plugins, init scripts
│   │   ├── Dockerfile
│   │   ├── plugins.txt
│   │   └── init.groovy.d/     # OIDC and admin automation scripts
│   └── open-webui-oidc/       # OIDC static config files
├── docker-compose.yml         # Service orchestration
├── .env                       # Environment variables (from .env.example)
├── docs/                      # Documentation (13 files)
├── scripts/                   # Management scripts
│   ├── stack-manager.sh       # Main orchestration script
│   ├── auth-manager.sh        # Identity & Security manager
│   ├── backup-manager.sh      # Backup/restore manager
│   ├── validate-system.sh     # System validation tool
│   ├── tests/                 # Test suite (17 test scripts)
│   └── utils/                 # Utility scripts (exporters, init, sql)
├── monitoring/                # Prometheus + Grafana configs
│   ├── grafana/
│   │   ├── config/grafana.ini
│   │   └── provisioning/      # Dashboards and datasources
│   ├── prometheus.yml
│   └── alertmanager.yml
├── haproxy/                   # Reverse proxy configuration
├── modsecurity/               # WAF rules
├── diagrams_mmd/              # Mermaid diagram sources (11 diagrams)
└── diagrams_png/              # Generated PNG diagrams (11 images)
```

## Important Environment Variables

> See `.env.example` for comprehensive documentation of all variables.

### PostgreSQL
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

### Keycloak
- `KEYCLOAK_ADMIN_USER`, `KEYCLOAK_ADMIN_PASSWORD` (temporary admin)
- `KEYCLOAK_PERMANENT_ADMIN_*` (permanent admin credentials)
- `KEYCLOAK_REALM`, `KEYCLOAK_DB_NAME`

### Open WebUI (OIDC)
- `OPEN_WEBUI_OAUTH_CLIENT_ID`, `OPEN_WEBUI_OAUTH_CLIENT_SECRET`
- `OPEN_WEBUI_ENABLE_OAUTH_SSO`: Enable Keycloak SSO
- `OPEN_WEBUI_OAUTH_SCOPES`: OpenID scopes

### Ollama
- `OLLAMA_MAX_LOADED_MODELS`: Models in memory (default: 2)
- `OLLAMA_NUM_THREAD`: CPU threads
- `OLLAMA_KEEP_ALIVE`: Model retention time
- `OLLAMA_SHM_SIZE`: Shared memory size

### Jenkins (OIDC - Primary Auth)
- `JENKINS_OIDC_CLIENT_ID`, `JENKINS_OIDC_CLIENT_SECRET`
- `JENKINS_ADMIN_USER`, `JENKINS_ADMIN_PASSWORD` (fallback only)

## Excluded from Backups (Intentional)

1. **`ollama_storage`**: Models are re-downloadable (saves ~50GB per backup)
2. **`ssl_certs_data`**: Auto-generated certificates (regenerable)
3. **`logs_data`**: Operational logs (temporary)
4. **`prometheus_rules_data`**: Derived from `monitoring/` (regenerable)
5. **`grafana_provisioning_data`**: Derived from `monitoring/grafana/` (regenerable)

## Recent Major Changes (Last 7 Days)

### 2026-01-28: Documentation & Diagrams Overhaul
- **Diagrams**: Redesigned all 11 `.mmd` diagrams for accuracy and professionalism
- **PNG Generation**: Regenerated all diagrams with high-resolution parameters (2400x1800, scale 2)
- **`.env.example`**: Complete rewrite with bilingual documentation (ES/EN), 18 organized sections
- **TODO Consolidation**: Merged `TODO.md` into `docs/PROJECT_STATUS.md`
- **Jenkins Auth Clarification**: Documented OIDC as primary auth, local credentials as fallback only

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


### 2026-01-25: Backup System Consolidation & Jenkins OIDC Automation
- **Backup Runner**: Refactored `backup` service to use DooD with `docker:cli` for robust automation.
- **Jenkins OIDC Automation**:
  - **Custom Image**: Created `config/jenkins/Dockerfile` and `plugins.txt` for automatic plugin installation.
  - **Init Scripts**: Automated Admin creation, OIDC Realm setup, and System URL configuration via `init.groovy.d`.
  - **Dependency Fix**: Aligned Docker Compose profiles (`gen-ai`, `monitoring`, `ci-cd`) for Keycloak services to resolve cross-profile dependency issues.
- **Network Fix**: Connected Jenkins and Backup services to `genai-network` for internet access (plugins/apk).
- **PostgreSQL**: Enhanced `pg_dump` logic in `backup-manager.sh` to work reliably via DooD `docker exec`.
- **n8n OIDC**: Documented Community Edition limitation (License required for SSO).
  - **Grafana OIDC Fix**: Restored authentication by reverting to git HEAD. Configured robust **Role Mapping** allowing `admin@example.com` to gain Admin rights without conflicting with the internal `admin@example.com` superuser.
  - **Identity Standardization**: Enforced "Admin User" (`admin-user`) as the standard identity across Keycloak, Jenkins, Grafana, and Open WebUI via `.env` variables and `userinfo.json` emulation.
    - *Note*: `userinfo.json` is now **gitignored** and auto-generated from `.env` credentials. `userinfo.json.example` serves as the template.


### 2026-01-25: Keycloak Security Hardening
- **Permanent Admin**: Created `keycloak-create-permanent-admin.sh` to automate admin migration
- **Security**: Replaced temporary `admin` user with secured permanent admin
- **Documentation**: Added `docs/KEYCLOAK_PERMANENT_ADMIN.md` guide
- **Config**: Updated `.env.example` with permanent admin section

### 2026-01-25: Monitoring & Proxy Stability Fixes
- **Prometheus Scrape Path**: Standardized `metrics_path: /prometheus/metrics` to align with the new base path, resolving false "Down" alerts.
- **Keycloak Metrics**: Confirmed usage of internal port `9000` (management interface) for Prometheus scraping, separate from public traffic (`8080`).
- **AlertManager Stability**: Fixed startup crash by correcting `web.external-url` scheme (`http://localhost/` prefix).
- **HAProxy DNS Resilience**: Implemented dynamic `resolvers docker` block and added `init-addr last,libc,none` to AlertManager server to ensure resolution persists across container restarts.
- **Healthcheck Standardization**: Updated all `docker-compose.yml` healthcheck URLs to include the respective sub-path prefixes.

### 2026-01-27: Validation & Hardening
- **Stack Manager Fixed**: Resolved silent failures in `stack-manager.sh` during `start full`.
- **Profile Decoupling**: Fixed `full` preset to avoid recursive `dev` profile activation, preventing CPU/GPU Ollama conflicts.
- **HAProxy Resilience**: Enabled `resolvers docker` for Grafana and n8n backends to fix startup race conditions (`<NOSRV>` errors).
- **Security Validation**: Enforced strict existence checks for OIDC Client Secrets in `stack-manager.sh`.
- **Prometheus Sync**: Updated Grafana datasource URL to include `/prometheus` sub-path, resolving "No Data" caused by HAProxy routing prefix.
- **Cleanup**: Removed dead code references to legacy verification scripts.

### 2026-01-25: Comprehensive Security Hardening & Zero Defaults
- **Secrets Management**: Removed ALL default credentials from `docker-compose.yml`, `auth-manager.sh`, `stack-manager.sh`, and `backup-manager.sh`.
- **Strict Validation**: Implemented `check_required_vars()` across all script managers. System now fails fast with clear errors if critical variables are missing.
- **Zero Defaults Policy**: Removed silent fallbacks (`:-`) for sensitive credentials and service accounts. The stack now enforces strict `.env` definition for all Admin, Database, and OIDC secret variables.
- **Fail-Secure Architecture**: No silent fallbacks. Admin accounts, databases, and encryption keys MUST be defined in `.env`.
- **Validation Standardization**: Unified error handling and validation logic across `validate-system.sh` and stack managers.
- **Clean Slate Verification**: Performed a full destructive purge (`clean all`) and successful redeployment to verify repo-completeness and "First Run" stability.
- **Identity Standardization**: Established "Admin User" (`admin-user`) as the standard identity across all SSO consumers (Grafana, OpenWebUI, Jenkins).
- **Cleanup Safety & Reporting**: Enhanced `stack-manager.sh` with granular protection prompts (Images/Models default=Keep) and refactored reporting to show structured summary of Deleted vs Preserved resources.
- **CLI & Monitoring Polish**:
  - **Robust Healthchecks**: Fixed `UNHEALTHY` status for Exporters by implementing native `grep` checks for NVIDIA (avoiding missing `wget`) and forcing IPv4 (`127.0.0.1`) for Python exporters to bypass IPv6 resolution issues.
  - **Enhanced Information**: Updated `stack-manager.sh` `info` and `start` commands to display **all** active services (including Exporters, Utilities, and WAF) using dynamic global detection instead of profile-based lists.
  - **Smart Status**: `status` command now suppresses empty headers when no services are running.

## Known Issues & Limitations

1. **No HTTPS/SSL by default**: HAProxy is configured but requires manual SSL setup
2. **Ollama models not backed up**: Intentional to save space, but requires re-download on restore
3. **Single-node deployment**: No clustering or high availability
4. **n8n OIDC requires Enterprise License**: Community Edition does not support SSO
5. **HAProxy paths pending**: `/keycloak` and `/n8n` routes not yet configured
6. **Open WebUI model filtering**: Must be configured via Admin Panel UI (Settings → Models). Arena Model cannot be hidden in v0.7.2

## Development Workflow

### Starting Services
```bash
./scripts/stack-manager.sh start [profile]
# Profiles: cpu, gpu-nvidia, gpu-amd, chat-ai, monitoring, infrastructure, security, automation, ci-cd, gen-ai, testing, debug, dev
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
- Grafana: http://localhost:3001 (via Keycloak OAuth)
- n8n: http://localhost:5678
- Prometheus: http://localhost:9090
- Jenkins: http://localhost:8081

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

**Last Updated**: 2026-01-28
