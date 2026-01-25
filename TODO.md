# TODO - my-selfhosted-ai-kit

## Completed ✅
- [x] **Restore Grafana OIDC**: Revived OIDC login via git history investigation.
- [x] **Identity Standardization**: Standardized "Ender Mujica" (emujicad) as the primary admin identity.
- [x] **Security Hardening (Deep Clean)**: Removed all insecure default credentials (`:-admin`, `:-postgres`, etc.) from `docker-compose.yml` and scripts.
- [x] **Strict Pre-flight Checks**: Updated `stack-manager.sh` to enforce `.env` variable existence (fail-fast).
- [x] **HAProxy Stability**: Fixed DNS startup race condition by adding `init-addr none`.
- [x] **Clean Slate Deployment**: Verified full destructive clean and redeploy flow.

## Pending ⏳
- [ ] Add certificate management (Certbot/Let's Encrypt).
- [ ] Integrate more LLM models (DeepSeek-R1 full version).
- [ ] Improve Grafana default dashboards.
