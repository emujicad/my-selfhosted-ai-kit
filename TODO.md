# My Self-Hosted AI Kit - TODO

## Critical Fixes (Blockers)
- [x] **CRITICAL FIX:** Remove invalid `depends_on: - ollama` in `test-runner` service (causes "undefined service" error preventing startup).
- [x] **Script Logic:** Fix silent failure in `stack-manager.sh` (trap errors during command substitution or remove `set -e` for eval).

## Core Fixes & Infrastructure
- [x] Configure HAProxy as central entry point (Port 80)
- [x] Fix Prometheus and Alertmanager asset loading issues
- [x] Implement sub-path routing for all monitoring services
- [x] Enable Prometheus native exporter in HAProxy
- [x] Fix Alertmanager startup crash (External URL scheme)
- [x] Fix Prometheus self-monitoring (Scrape path alignment)

## Security & Auth
- [ ] Configure Keycloak relative path for sub-directory access
- [ ] Implement HTTPS/SSL in HAProxy
- [ ] Enforce WAF rules for exposed services

## Features & Improvements
- [ ] **Infrastructure Fix:** Correct Prometheus Keycloak target from port 9000 to 8080 in `prometheus.yml`.
- [ ] **Script Maintenance:** Remove or restore missing scripts referenced in `stack-manager.sh` (`verify-env-variables.sh`, `validate-config.sh`, `verifica_modelos.sh`).
- [ ] **Security:** Add critical OIDC secrets to `REQUIRED_VARS` validation in `stack-manager.sh`.
- [ ] Add Jenkins to the proxy path (`/jenkins`)
- [ ] Implement n8n OIDC (requires license/check version)
- [ ] Add auto-healing for crashed containers (Watchtower is active)

## Done
- [x] Robust healthcheck paths for all sub-path services
- [x] Project documentation consolidation
- [x] Standardized Admin User identity
