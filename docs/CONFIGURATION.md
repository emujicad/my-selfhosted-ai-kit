# ⚙️ Configuration Management Guide

Complete guide for managing environment variables, dynamic configuration, and update strategies for all services.

**Last updated**: 2026-01-24

---

## 📋 Table of Contents

1. [Automatic .env Fixing](#automatic-env-fixing)
2. [Dynamic Environment Variables](#dynamic-environment-variables)
3. [Update Strategies](#update-strategies)
4. [Best Practices](#best-practices)

---

## 🔧 Automatic .env Fixing

### Overview

`.env` variable correction is now **automatic and transparent**. You no longer need to run a separate script.

### What Does It Do Automatically?

When you run `./scripts/stack-manager.sh start` or `./scripts/stack-manager.sh validate`, the system:

1. **Automatically verifies** if there are variables in `.env` that need quotes
2. **Automatically fixes** any problems found:
   - `*_SCOPES` variables with spaces without quotes
   - `WATCHTOWER_SCHEDULE` variable with spaces without quotes
3. **Creates a backup** automatically before modifying
4. **Reports** what was fixed (only if it fixed something)
5. **Continues** with validation normally

### Behavior

**If NO problems:**
- ✅ **Silent**: Shows nothing, just continues
- ✅ **Fast**: Doesn't delay validation

**If THERE ARE problems:**
- 🔧 Shows: "✅ .env file automatically corrected (X variables):"
- 📋 Lists what was fixed:
  - "• N8N_OIDC_SCOPES"
  - "• OPEN_WEBUI_OAUTH_SCOPES"
  - "• GRAFANA_OAUTH_SCOPES"
  - "• JENKINS_OIDC_SCOPES"
  - "• WATCHTOWER_SCHEDULE"
- 💾 Shows: "Backup saved at: .env.backup.YYYYMMDD_HHMMSS"
- ✅ Continues with validation normally

### Usage Example

```bash
# Validate (automatic correction included)
./scripts/stack-manager.sh validate

# Or when starting services (automatic correction included)
./scripts/stack-manager.sh start

# If there are problems, you'll see:
# ✅ .env file automatically corrected (3 variables):
#    • N8N_OIDC_SCOPES
#    • OPEN_WEBUI_OAUTH_SCOPES
#    • GRAFANA_OAUTH_SCOPES
#    Backup saved at: .env.backup.20260124_123456
```

### Comparison: Before vs Now

**❌ Before (Manual)**
```bash
# 1. Detect errors when sourcing .env
source .env
# profile: command not found
# email: command not found

# 2. Edit .env manually to add quotes
nano .env

# 3. Validate
./scripts/stack-manager.sh validate
```

**✅ Now (Automatic)**
```bash
# Only this:
./scripts/stack-manager.sh validate
# Or simply:
./scripts/stack-manager.sh start
# Everything is done automatically, transparent to the user
```

### Manual Correction (If Needed)

If you need to manually fix, you can directly edit `.env` file:

```bash
# Edit .env manually
nano .env

# Add quotes to variables with spaces:
# ❌ Before: N8N_OIDC_SCOPES=openid profile email
# ✅ After: N8N_OIDC_SCOPES="openid profile email"
```

But **normally not necessary** - correction is automatic.

### Configuration

Automatic correction is integrated into `stack-manager.sh` and runs:
- **Before validating** environment variables (in `validate_before_start`)
- **Automatically** when you run `validate` or `start`

Requires no additional configuration.

### What It Verifies

1. **SCOPES variables without quotes**: `N8N_OIDC_SCOPES=openid profile email` (without quotes)
2. **WATCHTOWER_SCHEDULE without quotes**: `WATCHTOWER_SCHEDULE=0 0 2 * * *` (without quotes)

### What It Fixes

1. **Adds quotes** to variables with spaces
2. **Creates backup** automatically before modifying
3. **Reports** what was fixed

### Security

- ✅ Creates backup automatically before modifying
- ✅ Only fixes specific known variables
- ✅ Doesn't modify other variables
- ✅ Silent if no problems (doesn't bother)

### Advantages

1. **Transparent**: User doesn't need to know it exists
2. **Automatic**: Runs only when necessary
3. **Fast**: Doesn't delay validation if no problems
4. **Informative**: Shows what was fixed if there were problems
5. **Safe**: Creates backup before modifying

### Restore Backup

If something goes wrong, you can restore the backup:

```bash
# List available backups
ls -la .env.backup.*

# Restore specific backup
cp .env.backup.20260124_123456 .env
```

---

## 🔄 Dynamic Environment Variables

### The Question

Could environment variables be outside the container and loaded from a volume when starting the container, thus avoiding having to recreate the container every time they change?

### Feasibility Analysis

#### Current Problem

**Current flow:**
1. You change variable in `docker-compose.yml` or `.env`
2. Docker Compose passes variables when **CREATING** the container
3. If container already exists, variables are NOT updated
4. You need to recreate to pass new variables

**Why?**
- Environment variables are passed to the process at startup
- Once started, process has its fixed variables
- Changing `.env` file doesn't affect running process

### Available Options

#### Option 1: Dynamic Configuration Files ✅ (Recommended)

**How it works:**
- Use configuration files (not environment variables)
- Application reads file from a volume
- Many applications can reload files without restarting

**Example with Grafana:**
```yaml
grafana:
  volumes:
    - ./monitoring/grafana/config/grafana.ini:/etc/grafana/grafana.ini:ro
```

**Advantages:**
- ✅ Doesn't require recreating container
- ✅ App can reload configuration
- ✅ Changes apply without restarting

**Limitations:**
- ❌ Not all applications support it
- ❌ Some configurations must be environment variables

**Applications that support it:**
- Grafana (reloads `grafana.ini`)
- n8n (can use configuration files)
- PostgreSQL (`postgresql.conf` files)

#### Option 2: Startup Script That Reads Variables

**How it works:**
- Create custom startup script
- Script reads variables from file in volume
- Exports variables before starting application

**Example:**
```yaml
services:
  app:
    volumes:
      - ./config/env:/config/env:ro
    entrypoint: ["/entrypoint.sh"]
```

**entrypoint.sh:**
```bash
#!/bin/bash
# Read variables from file
source /config/env
# Start application
exec /app/start.sh
```

**Advantages:**
- ✅ Variables outside container
- ✅ Can change file without modifying docker-compose.yml

**Limitations:**
- ❌ Still requires restarting container to apply changes
- ❌ More complex to maintain
- ❌ Requires modifying entrypoint of each service

#### Option 3: Use `.env` with Docker Compose (Current)

**How it works:**
- Docker Compose automatically loads `.env`
- Variables are passed to container when creating it

**Advantages:**
- ✅ Standard and simple
- ✅ Well documented
- ✅ Works with all applications

**Limitations:**
- ❌ Requires recreating container to apply changes
- ❌ Variables mixed with Docker Compose configuration

#### Option 4: Hybrid Configuration ⭐ **RECOMMENDED**

**How it works:**
- Critical variables: Environment variables (require recreate)
- Dynamic configuration: Configuration files (don't require recreate)

**Example:**
```yaml
services:
  grafana:
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}  # Critical, requires recreate
    volumes:
      - ./config/grafana.ini:/etc/grafana/grafana.ini:ro  # Dynamic, reloads
```

### Recommendation

#### For Most Cases: **Option 4 (Hybrid Configuration)**

**Why:**
- Many applications support configuration file reloading
- Doesn't require recreating container for dynamic configuration
- More flexible and maintainable
- Keep environment variables only for critical credentials

**Practical example:**
```yaml
services:
  grafana:
    volumes:
      # Dynamic configuration (reloads)
      - ./monitoring/grafana/config/grafana.ini:/etc/grafana/grafana.ini:ro
    environment:
      # Only critical variables that require recreating
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
```

### When to Use Each

**When to use environment variables:**
- Credentials and secrets (passwords, API keys)
- Configuration that app only reads at startup
- Variables that Docker Compose needs for configuration

**When to use configuration files:**
- Configuration that may change frequently
- Configuration that app can reload
- Complex configuration (multiple values)

### Practical Implementation

#### Step 1: Identify Dynamic Configurations

Review which configurations can be files instead of variables:

- ✅ Grafana: `grafana.ini` (already implemented)
- ✅ n8n: Configuration files
- ✅ PostgreSQL: `postgresql.conf`
- ❌ Open WebUI: Most are environment variables
- ❌ Keycloak: Most are environment variables

#### Step 2: Move to Configuration Files

For each service that supports it:
1. Create configuration file
2. Mount it as volume
3. Remove equivalent environment variables

#### Step 3: Keep Critical Variables

Only keep as environment variables:
- Credentials and secrets
- Configuration that requires recreating container
- Variables that Docker Compose needs

### Comparison

| Method | Requires Recreate | Complexity | Flexibility | Compatibility |
|--------|------------------|-------------|--------------|---------------|
| Environment variables | ✅ Yes | ⭐ Low | ⭐⭐ Medium | ✅ All apps |
| Configuration files | ❌ No | ⭐⭐ Medium | ⭐⭐⭐ High | ⚠️ Depends on app |
| Startup script | ✅ Yes | ⭐⭐⭐ High | ⭐⭐⭐ High | ✅ All apps | |
| Hybrid | ⚠️ Partial | ⭐⭐ Medium | ⭐⭐⭐ High | ✅ All apps |

### Conclusion

**Is it feasible?** ✅ Yes, but with limitations:

1. **For dynamic configurations**: Use configuration files mounted as volumes
2. **For critical variables**: Keep as environment variables
3. **Hybrid approach**: Combine both according to need

**Final recommendation:**
- Use configuration files when application supports it
- Keep environment variables for credentials and critical configurations
- Accept that some configurations will require recreating container

---

## 🔄 Update Strategies

### n8n Update Strategy

#### Current Situation

- **Current version**: 1.101.2
- **Latest version**: 1.122.5
- **Versions behind**: 21
- **Time without updating**: 4 months

#### Risks of Updating

1. **Database migrations**: n8n may require DB migrations between versions
2. **Breaking changes**: Some versions may have incompatible changes
3. **Broken workflows**: Workflows may stop working if they use deprecated functionality
4. **Outdated nodes**: Some custom nodes may not be compatible

#### Recommendation: Controlled Update

**Option 1: Gradual Update (RECOMMENDED)**

**Advantages**:
- Lower risk of breaking workflows
- Can test each version before continuing
- Easy rollback if something fails

**Steps**:

1. **Make complete backup BEFORE updating**:
   ```bash
   ./scripts/backup-manager.sh backup --full --verify
   ```

2. **Update to intermediate version first** (e.g., 1.110):
   ```yaml
   image: docker.n8n.io/n8nio/n8n:1.110.1
   ```

3. **Restart and verify**:
   ```bash
   docker compose up -d --force-recreate n8n
   # Wait for it to start
   # Verify workflows work
   ```

4. **If everything is fine, continue to latest version**:
   ```yaml
   image: docker.n8n.io/n8nio/n8n:1.122.5
   ```

**Option 2: Direct Update to Latest**

**Only if**:
- You have recent backup
- You don't have critical workflows in production
- You can afford downtime

**Steps**:

1. **Complete backup**:
   ```bash
   ./scripts/backup-manager.sh backup --full --verify
   ```

2. **Update docker-compose.yml**:
   ```yaml
   image: docker.n8n.io/n8nio/n8n:latest
   ```

3. **Restart**:
   ```bash
   docker compose up -d --force-recreate n8n
   ```

4. **Verify automatic migrations**:
   n8n runs migrations automatically at startup

**Option 3: Pin Specific Version (SAFEST)**

**For production**, pin a stable version:

```yaml
image: docker.n8n.io/n8nio/n8n:1.122.5
```

**Advantages**:
- Full control over when to update
- Avoids unexpected automatic updates
- Can test in development first

#### Recommended Configuration

**1. Pin Version in docker-compose.yml**

```yaml
x-n8n: &service-n8n
  image: docker.n8n.io/n8nio/n8n:1.122.5  # Specific version
  # Instead of: docker.n8n.io/n8nio/n8n (latest)
```

**2. Disable Watchtower for n8n (if active)**

If you have Watchtower active, exclude n8n from automatic updates:

```yaml
watchtower:
  environment:
    - WATCHTOWER_LABEL_ENABLE=false
    # Or label n8n to exclude it
```

Or label n8n:
```yaml
n8n:
  labels:
    - "com.centurylinklabs.watchtower.enable=false"
```

#### Checklist Before Updating

- [ ] Complete backup done (`./scripts/backup-manager.sh backup --full --verify`)
- [ ] Verify PostgreSQL is running and accessible
- [ ] Document critical workflows (just in case)
- [ ] Have rollback plan (restore backup if it fails)
- [ ] Test during low usage hours if possible

#### What to Do If Something Goes Wrong

1. **Stop n8n**:
   ```bash
   docker compose stop n8n
   ```

2. **Restore backup**:
   ```bash
   ./scripts/backup-manager.sh restore <backup-timestamp>
   ```

3. **Restart services**:
   ```bash
   docker compose restart
   ```

#### Final Recommendation

**For your case (21 versions behind)**:

1. ✅ **Make complete backup NOW**
2. ✅ **Update gradually**: First to 1.110, then to 1.122
3. ✅ **Pin specific version** in docker-compose.yml (don't use `latest`)
4. ✅ **Test critical workflows** after each update
5. ✅ **Update manually** every month or two (not automatic)

**NOT recommended**:
- ❌ Automatic update with Watchtower for n8n
- ❌ Jump directly from 1.101 to 1.122 without testing
- ❌ Update without backup

### General Update Strategy for All Services

**Principles:**
1. **Never use `latest` in production** - Always pin specific versions
2. **Always backup before updating** - Complete verified backups
3. **Test in development first** - If you have dev environment
4. **Update gradually** - Especially for services many versions behind
5. **Document changes** - Note what changed and why
6. **Have rollback plan** - Know how to return to previous version
7. **Update during low usage** - Minimize impact on users

**Service Priority:**
- **High priority (update frequently)**: Security services (Keycloak, ModSecurity)
- **Medium priority**: Infrastructure (PostgreSQL, Redis)
- **Low priority**: Stable services (n8n, Grafana, Ollama)

---

## 📚 Best Practices

### Environment Variables

1. **Use `.env` for secrets** - Never commit secrets to git
2. **Use `.env.example` as template** - Document required variables
3. **Keep `.env` backed up** - Include in backup strategy
4. **Validate before starting** - Use `stack-manager.sh validate`

### Configuration Files

1. **Use volumes for dynamic config** - Easier to change without recreate
2. **Keep original configs backed up** - In case need to restore
3. **Document changes** - Comment why changes were made
4. **Test changes before applying** - In development if possible

### Updates

1. **Pin versions** - Avoid `latest` in production
2. **Backup before updating** - Always
3. **Test updates** - In development environment
4. **Update gradually** - One service at a time
5. **Document** - Keep update log

### Security

1. **Change default passwords** - Immediately after setup
2. **Use strong passwords** - Generate with password manager
3. **Rotate secrets regularly** - At least quarterly
4. **Audit access** - Review who has access to what
5. **Keep services updated** - Security patches

---

*Last updated: 2026-01-24*
