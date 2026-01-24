# 🔧 Troubleshooting Guide

Comprehensive troubleshooting guide for all services in the stack.

**Last updated**: 2026-01-24

---

## 📋 Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Service-Specific Troubleshooting](#service-specific-troubleshooting)
3. [Common Problems](#common-problems)
4. [Database Issues](#database-issues)
5. [Network and Connectivity](#network-and-connectivity)
6. [Performance Issues](#performance-issues)

---

## ⚡ Quick Diagnostics

### Run Stack Diagnostics

```bash
# Quick validation
./scripts/stack-manager.sh validate

# Check service status
./scripts/stack-manager.sh status

# View logs for problematic service
./scripts/stack-manager.sh logs <service-name>

# Full diagnosis for Keycloak database
./scripts/stack-manager.sh diagnose keycloak-db
```

### Check Docker Health

```bash
# Check running containers
docker ps

# Check container logs
docker logs <container-name>

# Check resource usage
docker stats

# Check networks
docker network ls
docker network inspect genai-network
```

---

## 🔍 Service-Specific Troubleshooting

### Keycloak

**Problem: Keycloak won't start or is very slow**

**Possible causes**:
1. Pending database transactions
2. Old locks in `databasechangeloglock`
3. Orphaned connections
4. Database not ready

**Automatic fix**: Already integrated! Just run:
```bash
./scripts/stack-manager.sh start security
```

The system automatically fixes database issues transparently.

**Manual diagnosis (optional)**:
```bash
./scripts/stack-manager.sh diagnose keycloak-db
```

**Problem: "Invalid redirect URI" error**

**Solution**:
1. Verify redirect URI in Keycloak client matches application configuration exactly
2. Include protocol (`http://`), host, port and complete path
3. No trailing slash unless application includes it

```bash
# Example correct redirect URIs:
# Grafana: http://localhost:3001/login/generic_oauth
# Open WebUI: http://localhost:3000/oauth/oidc/callback
# n8n: http://localhost:5678/rest/oauth2-credential/callback
```

**Problem: "Client authentication failed"**

**Solution**:
1. Verify client secret in `.env` matches Keycloak
2. Verify client has "Client authentication: On" in Keycloak
3. Recreate client if necessary

**Problem: "Cannot remove last organization admin" (Grafana)**

**Solution**: This is solved in our configuration:
- `fullScopeAllowed` set to `false `
- `roles` scope in **Optional** (not Default)
- `SKIP_ORG_ROLE_SYNC=true` in Grafana

If you still see this, verify Grafana client configuration in Keycloak.

**See also**: [`KEYCLOAK_GUIDE.md`](KEYCLOAK_GUIDE.md) for complete Keycloak troubleshooting.

---

### Open WebUI

**Problem: SSO login fails with 401 error**

**Status**: ✅ Solved with "Emulated OIDC Environment" solution

Our solution uses:
- `oidc-config.json`: Fake discovery with split-horizon routing
- `userinfo.json`: Fake UserInfo endpoint

**If experiencing issues**:
1. Verify `oidc-config.json` and `userinfo.json` are mounted correctly
2. Check `OPENID_PROVIDER_URL=http://127.0.0.1:8080/static/oidc-config.json`
3. Restart Open WebUI: `docker compose restart open-webui`

**Problem: Admin user not recognized**

**Solution**: Verify admin account in SQLite:
```bash
docker exec open-webui sqlite3 /app/backend/data/webui.db "SELECT * FROM user WHERE email='emujicad@gmail.com';"
```

**See full details**: [`KEYCLOAK_GUIDE.md`](KEYCLOAK_GUIDE.md#open-webui--keycloak)

**Problem: Embedding models appear in chat model list**

**Symptoms**:
- Models like `all-minilm:latest` and `nomic-embed-text:latest` appear in the chat interface
- Selecting these models causes error: `400: "all-minilm:latest" does not support chat`
- These are embedding models, not chat models

**Why this happens**:
- Ollama exposes all models through its `/api/tags` endpoint
- Open WebUI lists all available models without filtering by capability
- Embedding models are designed for text vectorization, not conversation

**Solution 1: Hide models via Open WebUI Admin Panel (Recommended)**

This is the **official and persistent** way to hide models:

1. Access Open WebUI at `http://localhost:3000`
2. Login as administrator (via Keycloak)
3. Click your profile icon → **"Admin Panel"** or **"Settings"**
4. Navigate to **"Workspace"** → **"Models"** (or **"Admin Settings"** → **"Models"**)
5. Find the embedding models:
   - `all-minilm:latest`
   - `nomic-embed-text:latest`
6. For each model, toggle **"Show in chat"** to OFF or mark as **"Hidden"**
7. Save changes

**Result**: Models will be hidden from the chat interface but remain available for embeddings/RAG functionality.

**Solution 2: Remove embedding models from Ollama (Not Recommended)**

Only if you don't need embeddings:

```bash
# List all models
docker exec ollama ollama list

# Remove embedding models (WARNING: This disables RAG functionality!)
docker exec ollama ollama rm all-minilm:latest
docker exec ollama ollama rm nomic-embed-text:latest
```

**⚠️ WARNING**: This will break RAG (Retrieval-Augmented Generation) features in Open WebUI.

**Solution 3: Use Ollama model tags (Advanced)**

Rename models with custom tags to differentiate them:

```bash
# Tag embedding models with 'embedding-' prefix
docker exec ollama ollama tag all-minilm:latest embedding-minilm:latest
docker exec ollama ollama tag nomic-embed-text:latest embedding-nomic:latest

# Remove original tags
docker exec ollama ollama rm all-minilm:latest
docker exec ollama ollama rm nomic-embed-text:latest

# Update Open WebUI embedding configuration
# In docker-compose.yml, update:
# - RAG_EMBEDDING_MODEL=embedding-minilm:latest
```

**Why environment variables don't work**:

Open WebUI v0.7.x does **not** support the following environment variables for model filtering:
- ❌ `ENABLE_MODEL_FILTER` (doesn't exist)
- ❌ `MODEL_FILTER_LIST` (doesn't exist)
- ❌ `DEFAULT_MODELS` (exists but doesn't hide models, only sets defaults)

Model visibility must be configured through the **Admin Panel** or **database**.

**Recommended approach**: Use **Solution 1** (Admin Panel) - it's persistent, official, and doesn't break functionality.

---

### Grafana

**Problem: Dashboards show "No data"**

**Causes**:
1. Exporters not running
2. Prometheus not scraping metrics
3. Incorrect time range

**Solution**:
```bash
# 1. Verify exporters are running
docker compose --profile monitoring ps node-exporter cadvisor postgres-exporter nvidia-exporter ollama-exporter

# 2. Start missing exporters
docker compose --profile monitoring up -d node-exporter cadvisor postgres-exporter nvidia-exporter ollama-exporter

# 3. Verify Prometheus is scraping
# Open http://localhost:9090/targets
# Exporters should show as "UP"

# 4. In Grafana:
# - Change time range to "Last 5 minutes" or "Last 15 minutes"
# - Refresh dashboard
# - Wait 1-2 minutes for metrics to accumulate
```

**Problem: PostgreSQL Status shows "Exporter Not Connected"**

**Cause**: postgres-exporter cannot connect to PostgreSQL

**Solutions**:
1. Verify password in `.env` matches PostgreSQL's
2. Ver ify postgres-exporter is in same network as postgres (`genai-network`)
3. Check PostgreSQL authentication configuration

**Problem: Panels show container IDs instead of names**

**This is normal**: cAdvisor uses `/system.slice/docker-<hash>.scope` format, not container names.

**See full details**: [`MONITORING_GUIDE.md`](MONITORING_GUIDE.md#troubleshooting)

---

### Ollama

**Problem: Models load slowly**

**Verify optimizations are applied**:
```bash
# Check environment variables
docker exec ollama env | grep OLLAMA

# Should show:
# OLLAMA_MAX_LOADED_MODELS=2
# OLLAMA_NUM_THREAD=8
# OLLAMA_KEEP_ALIVE=10m
```

**If not applied**:
```bash
docker compose up -d --force-recreate ollama-gpu
```

**Problem: Cache not working**

**Verify KEEP_ALIVE**:
```bash
docker exec ollama env | grep OLLAMA_KEEP_ALIVE
```

**Test cache**:
```bash
# Load model
docker exec ollama ollama run all-minilm:latest "test"

# Load again (should be instant)
time docker exec ollama ollama run all-minilm:latest "test"
```

**Problem: High memory usage**

**Adjust configuration**:
1. Reduce `OLLAMA_MAX_LOADED_MODELS` in `.env`
2. Use smaller models
3. Reduce `OLLAMA_KEEP_ALIVE`

**See full details**: [`OLLAMA_GUIDE.md`](OLLAMA_GUIDE.md#troubleshooting)

---

### PostgreSQL

**Problem: Connection refused**

**Check service is running**:
```bash
docker compose ps postgres
```

**Check logs**:
```bash
docker logs postgres
```

**Verify network**:
```bash
docker network inspect genai-network | grep -A 5 postgres
```

**Problem: "Too many connections"**

**Check active connections**:
```bash
docker exec postgres psql -U admin -d postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

**Terminate idle connections**:
```bash
docker exec postgres psql -U admin -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND pid <> pg_backend_pid();"
```

---

### n8n

**Problem: Workflows not executing**

**Check service is running**:
```bash
docker compose ps n8n
```

**Check logs**:
```bash
docker logs n8n
```

**Verify database connection**:
```bash
docker exec postgres psql -U admin -l | grep n8n
```

**Problem: After update, workflows broken**

**Solution**:
1. Stop n8n
2. Restore backup
3. Update gradually (see [`CONFIGURATION.md`](CONFIGURATION.md#update-strategies))

---

## 🌐 Common Problems

### Docker Compose Issues

**Problem: "Service 'X' depends on service 'Y' which is undefined"**

**Solution**: Use `stack-manager.sh` which handles dependencies automatically:
```bash
./scripts/stack-manager.sh start <profile>
```

Instead of:
```bash
docker compose --profile <profile> up -d
```

**Problem: "Port already in use"**

**Find what's using the port**:
```bash
sudo lsof -i :<port-number>
```

**Kill the process or change port in docker-compose.yml**.

**Problem: "Container name already exists"**

**Solution**:
```bash
# Remove existing container
docker rm <container-name>

# Or force recreate
docker compose up -d --force-recreate <service-name>
```

---

### Environment Variables

**Problem: ".env variables not applied"**

**Automatic fix**: Already handled! Just run:
```bash
./scripts/stack-manager.sh validate
```

This automatically fixes variables with spaces that need quotes.

**Manual verification**:
```bash
# Verify variable in container
docker exec <container> env | grep <VARIABLE_NAME>
```

**If still not applied**:
```bash
# Recreate container to apply new variables
docker compose up -d --force-recreate <service-name>
```

**See details**: [`CONFIGURATION.md`](CONFIGURATION.md#automatic-env-fixing)

---

### Network Issues

**Problem: "Connection refused" to keycloak:8080**

**From browser**: Use `localhost:8080` (browser cannot resolve `keycloak`)
**From container**: Use `keycloak:8080` (internal Docker network)

**Key rule**:
- Browser → `localhost:8080`
- Container → `keycloak:8080`

**Problem: Services can't communicate**

**Verify network**:
```bash
# Check services are in same network
docker network inspect genai-network

# Test connectivity from one container to another
docker compose exec service1 ping service2
```

---

### Authentication Issues

**Problem: "Login provider denied login request"**

**Solutions**:
1. **Clear cookies**: Use incognito window
2. **Clear sessions**: `docker compose --profile security restart keycloak`
3. **Verify user exists**: Check in Keycloak admin console

**Problem: OAuth redirect doesn't work**

**Check**:
1. Redirect URI exactly matches in Keycloak and application
2. No typos in URLs
3. Client is configured correctly (standard flow enabled)

---

## 💾 Database Issues

### Keycloak Database

**Automatic cleaning**: Integrated into `stack-manager.sh`

**What it fixes automatically**:
- Pending transactions
- Old locks in `databasechangeloglock`
- Orphaned connections

**Manual diagnosis (optional)**:
```bash
./scripts/stack-manager.sh diagnose keycloak-db
```

**Why database problems occur**:
1. System restart (Docker stops abruptly)
2. `docker compose down` (sometimes too fast)
3. Network problems
4. Out of memory (OOM Killer)
5. Keycloak crashes

**Safety**: Completely safe - only terminates dead connections, doesn't modify data.

**See full details**: [`KEYCLOAK_GUIDE.md`](KEYCLOAK_GUIDE.md#database-issues)

---

### PostgreSQL Performance

**Problem: Slow queries**

**Check active queries**:
```bash
docker exec postgres psql -U admin -d postgres -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state = 'active';"
```

**Terminate long-running query**:
```bash
docker exec postgres psql -U admin -d postgres -c "SELECT pg_terminate_backend(<pid>);"
```

**Problem: High memory usage**

**Check cache hit ratio**:
```bash
docker exec postgres psql -U admin -d postgres -c "SELECT sum(heap_blks_read) as heap_read, sum(heap_blks_hit) as heap_hit, sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio FROM pg_statio_user_tables;"
```

Target: >95% hit ratio

---

## ⚡ Performance Issues

### High CPU Usage

**Identify culprit**:
```bash
docker stats --no-stream

# Or with stack-manager
./scripts/stack-manager.sh monitor
```

**Common causes**:
- Ollama running inference
- n8n executing workflows
- Prometheus scraping metrics

**Solutions**:
1. **Ollama**: Adjust `OLLAMA_NUM_THREAD` in `.env`
2. **Resource limits**: Configure in `docker-compose.yml`
3. **Reduce scrape intervals**: In `monitoring/prometheus.yml`

### High Memory Usage

**Check per container**:
```bash
docker stats --format "table {{.Name}}\t{{.MemUsage}}"
```

**Common culprits**:
- Ollama with multiple models loaded
- PostgreSQL query cache
- Prometheus metrics retention

**Solutions**:
1. **Ollama**: Reduce `OLLAMA_MAX_LOADED_MODELS`
2. **PostgreSQL**: Adjust `shared_buffers` and `effective_cache_size`
3. **Prometheus**: Reduce `--storage.tsdb.retention.time`

### Disk Space Issues

**Check usage**:
```bash
df -h
docker system df
```

**Clean up**:
```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes (CAREFUL!)
docker volume prune

# Complete cleanup
docker system prune -a --volumes
```

**Exclude from backups**:
- `ollama_storage` volume (models - very large)
-Temporary caches

**See**: [`BACKUP_GUIDE.md`](BACKUP_GUIDE.md) for backup optimization

---

## 📊 Monitoring and Observability

### No Metrics Showing

**Check exporters**:
```bash
# Verify all exporters are running
docker compose --profile monitoring ps

# Check specific exporter
curl http://localhost:9100/metrics  # node-exporter
curl http://localhost:9099/metrics  # ollama-exporter
curl http://localhost:9400/metrics  # nvidia-exporter (if GPU)
```

**Check Prometheus targets**:
- Open http://localhost:9090/targets
- All targets should be "UP"

**If targets are DOWN**:
1. Check service is running
2. Verify network connectivity
3. Check firewall rules

### Grafana Connection Issues

**Problem: Can't access Grafana**

**Check**:
```bash
# Verify Grafana is running
docker compose ps grafana

# Check logs
docker logs grafana

# Verify port 3001 is accessible
curl http://localhost:3001
```

**Problem: Can't login with Keycloak**

**See**: [Keycloak troubleshooting](#keycloak) above

---

## 🔄 Recovery Procedures

### Complete Stack Reset

**⚠️ WARNING**: This will delete ALL data!

```bash
# 1. Stop all services
docker compose down

# 2. Remove all volumes (DELETES DATA!)
docker volume rm $(docker volume ls -q | grep my-selfhosted-ai-kit)

# 3. Start fresh
./scripts/stack-manager.sh start default
```

### Restore from Backup

```bash
# 1. List available backups
./scripts/backup-manager.sh list

# 2. Restore specific backup
./scripts/backup-manager.sh restore <timestamp>

# 3. Verify restoration
./scripts/stack-manager.sh validate
```

**See**: [`BACKUP_GUIDE.md`](BACKUP_GUIDE.md) for complete backup/restore procedures

---

## � Automatic Fixes

### Overview

The system includes **integrated automatic fixes** that run transparently. You no longer need to run separate scripts for common problems.

### Available Automatic Fixes

#### 1. .env Variables Without Quotes

**When it runs**: Automatically during `validate` or `start`

**What it fixes**:
- `*_SCOPES` variables with spaces without quotes
- `WATCHTOWER_SCHEDULE` variable with spaces without quotes

**Behavior**:
- ✅ Silent if no problems
- ✅ Creates backup automatically
- ✅ Reports what was fixed if there were problems

#### 2. Keycloak Database

**When it runs**: Automatically during `start` when using `security` profile

**What it fixes**:
- Pending transactions (`idle in transaction`)
- Old locks in `databasechangeloglock` (older than 5 minutes)
- Hung locks in `databasechangeloglock` table

**Behavior**:
- ✅ Silent if no problems
- ✅ Only fixes real problems (doesn't touch active connections)
- ✅ Reports what was fixed if there were problems

#### 3. Automatic Keycloak Initialization (Docker Compose)

**When it runs**: Automatically when starting services with `security` profile

**What it does**:
- **`keycloak-db-init`**: Automatically creates Keycloak database if it doesn't exist (before Keycloak starts)
- **`keycloak-init`**: Automatically creates OIDC clients (Grafana, n8n, Open WebUI, Jenkins) and **automatically updates secrets in `.env`** (after Keycloak is ready)
- **`grafana-db-init`**: Automatically creates Grafana database if it doesn't exist (before Grafana starts)

**Behavior**:
- ✅ Runs automatically without manual intervention
- ✅ Creates OIDC clients with correct configuration
- ✅ Automatically updates secrets in `.env`
- ✅ Injects user link in Grafana database for OAuth login

### Workflow Comparison

**Before (Manual)**:
```bash
# 1. Detect problem
source .env
# profile: command not found

# 2. Manually fix by editing .env
nano .env

# 3. If Keycloak doesn't start
./scripts/keycloak-manager.sh fix-db

# 4. Finally start
./scripts/stack-manager.sh start
```

**Now (Automatic)**:
```bash
# Just this:
./scripts/stack-manager.sh start

# Everything happens automatically:
# ✅ Fixes .env variables if needed
# ✅ Fixes Keycloak database if needed
# ✅ Reports what was fixed (only if it fixed something)
# ✅ Starts services normally
```

### When Fixes Run

| Fix | When It Runs | Where |
|-----|--------------|-------|
| .env variables | `validate` or `start` | `validate_before_start()` |
| Keycloak database | `start` with `security` profile | `auto_fix_keycloak_db()` |
| Keycloak DB init | `start` with `security` profile | `keycloak-db-init` (Docker Compose) |
| Grafana DB init | `start` with `monitoring` profile | `grafana-db-init` (Docker Compose) |
| OIDC clients creation | `start` with `security` profile | `keycloak-init` (Docker Compose) |

### Manual Scripts (Diagnosis Only)

**Only for detailed diagnosis**:
- `stack-manager.sh diagnose keycloak-db` - Detailed Keycloak database diagnosis
- `keycloak-manager.sh fix-db` - Wrapper that uses `stack-manager.sh diagnose keycloak-db`

**Note**: .env variable fixing is completely integrated and automatic. There's no manual script for this - just edit `.env` directly if you need to make manual changes.

---

## 🔄 Docker Compose: Restart vs Recreate

### Command Differences

#### 1. `docker compose restart <service>`

**What it does**:
- Only restarts existing container
- Does NOT reload environment variables from `docker-compose.yml`
- Does NOT apply image changes
- Does NOT apply changes to volumes, ports, configuration

**When to use**:
- Service failed and you just need to restart it
- You haven't changed anything in `docker-compose.yml`
- You need a quick restart without applying changes

**Example**:
```bash
docker compose restart grafana
```

#### 2. `docker compose up -d --force-recreate <service>`

**What it does**:
- Destroys and completely recreates container
- DOES reload environment variables from `docker-compose.yml`
- DOES apply image changes (if updated)
- DOES apply changes to volumes, ports, configuration

**When to use**:
- You changed environment variables in `docker-compose.yml`
- You updated the image (`docker pull`)
- You changed volumes, ports, or configuration
- You need to force recreation even if Docker doesn't detect changes

**Example**:
```bash
docker compose up -d --force-recreate grafana
```

#### 3. `docker compose up -d <service>`

**What it does**:
- Only recreates if Docker automatically detects changes
- More efficient than `--force-recreate`
- Applies changes when it detects them

**When to use**:
- Docker can detect changes automatically
- More safe and efficient than `--force-recreate`
- Preferred when you don't need to force recreation

**Example**:
```bash
docker compose up -d grafana
```

### Practical Examples

**Case 1: Changed an Environment Variable**

In `docker-compose.yml`:
```yaml
environment:
  - NEW_VAR=value
```

- ❌ `docker compose restart` → Does NOT apply the change
- ✅ `docker compose up -d --force-recreate` → DOES apply the change

**Case 2: Updated the Image**

```bash
docker pull quay.io/keycloak/keycloak:latest
```

- ❌ `docker compose restart` → Still uses old image
- ✅ `docker compose up -d --force-recreate` → Uses new image

**Case 3: Just Need to Restart Due to Error**

- ✅ `docker compose restart` → Sufficient and faster

### Why Use `--force-recreate`?

**Main reason: Environment Variables**

When you change environment variables in `docker-compose.yml`, you need to recreate the container for new variables to load. A simple `restart` only restarts the process inside the container but doesn't reload `docker-compose.yml` configuration.

**Example**:
```yaml
# Before
environment:
  - DEBUG=false

# After (changed to true)
environment:
  - DEBUG=true
```

With `restart`: Container still uses `DEBUG=false`  
With `--force-recreate`: Container uses `DEBUG=true`

**Other reasons**:

1. **Updated images**: When you update an image (`docker pull`), you need to recreate to use the new version
2. **Configuration changes**: Any change in `docker-compose.yml` (volumes, ports, commands, etc.) requires recreating the container
3. **Force update**: Sometimes Docker doesn't detect changes automatically, `--force-recreate` forces recreation

### Summary Table

| Command | Reloads Variables | Applies Image Changes | Applies Config Changes | Speed |
|---------|-------------------|----------------------|----------------------|-------|
| `restart` | ❌ | ❌ | ❌ | ⚡ Fast |
| `up -d` | ✅ | ✅ | ✅ | 🚀 Medium |
| `up -d --force-recreate` | ✅ | ✅ | ✅ | 🐢 Slow |

### Recommendation

- **Use `restart`** when you only need to restart without changes
- **Use `up -d`** when Docker can detect changes automatically
- **Use `up -d --force-recreate`** when you need to force applying changes

---

## �📚 Additional Resources

### Service-Specific Guides

- **[KEYCLOAK_GUIDE.md](KEYCLOAK_GUIDE.md)** - Complete Keycloak troubleshooting
- **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** - Monitoring and metrics troubleshooting
- **[OLLAMA_GUIDE.md](OLLAMA_GUIDE.md)** - Ollama optimization and troubleshooting
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration management
- **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - Validation and testing

### Stack Management

- **[STACK_MANAGER_GUIDE.md](STACK_MANAGER_GUIDE.md)** - Complete stack management guide
- **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)** - Backup and recovery procedures

### Community and Support

- Check GitHub Issues for known problems
- Review Docker Compose logs for detailed error messages
- Use `stack-manager.sh diagnose` for automated diagnostics

---

## 🆘 Getting Help

### Before Asking for Help

1. **Check this guide** for your specific problem
2. **Run diagnostics**: `./scripts/stack-manager.sh validate`
3. **Check logs**: `./scripts/stack-manager.sh logs <service-name>`
4. **Review recent changes**: Did you change configuration recently?

### Information to Provide

When seeking help, provide:
1. **Error message** (exact text)
2. **Service logs** (from `docker logs <service>`)
3. **Docker Compose version**: `docker compose version`
4. **OS and version**: `uname -a`
5. **What you changed** recently
6. **Steps to reproduce** the problem

---

*Last updated: 2026-01-24*
