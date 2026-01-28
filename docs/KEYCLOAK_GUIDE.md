# 🔐 Keycloak Integration Guide

Complete guide for integrating Keycloak with all services in the stack, including troubleshooting and automatic fixes.

**Last updated**: 2026-01-28

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Key Concepts](#key-concepts)
3. [Credentials and Access](#credentials-and-access)
4. [Service Integrations](#service-integrations)
   - [Grafana + Keycloak](#grafana--keycloak) ✅
   - [Open WebUI + Keycloak](#open-webui--keycloak) ✅
   - [n8n + Keycloak (Licensing Note)](#n8n--keycloak) ⚠️
   - [Jenkins + Keycloak](#jenkins--keycloak) ✅
5. [Troubleshooting](#troubleshooting)
6. [Database Issues](#database-issues)
7. [References](#references)

---

## 📊 Overview

### ⚡ Automatic Initialization

The system includes automated services that simplify configuration:

- **`keycloak-db-init`**: Automatically creates Keycloak database if it doesn't exist (before Keycloak starts)
- **`keycloak-init`**: Automatically creates OIDC clients (Grafana, n8n, Open WebUI, Jenkins) and **updates secrets in `.env`** (after Keycloak is ready)
- **`grafana-db-init`**: Automatically creates Grafana database if it doesn't exist

**This means you normally only need:**
```bash
./scripts/stack-manager.sh start security monitoring automation
```

OIDC clients and secrets are configured automatically. You only need to run manual scripts if you want total control or if something fails.

### Integration Status

| Service | Status | Notes |
|---------|--------|-------|
| **Grafana** | ✅ Complete | Works perfectly. Clients created automatically by `keycloak-init` |
| **Open WebUI** | ✅ Complete | Emulated OIDC Environment solution implemented |
| **n8n** | ⚠️ Limited | OIDC configs disabled (Community Edition limitation) |
| **Jenkins** | ✅ Complete | Fully automated via `init.groovy.d` scripts. |

---

## 🔑 Key Concepts

### URLs in Docker

**Fundamental rule:**
- `localhost:8080` → For browser access (user)
- `keycloak:8080` → For Docker container access (internal)

**Why:**
- User's browser CANNOT resolve `keycloak` (it's an internal Docker name)
- Containers CAN resolve `keycloak` through Docker network
- Using `keycloak:8080` for internal communication is more efficient

### Standard OAuth/OIDC Flow

```
1. User clicks "Sign in with Keycloak"
2. Browser redirects to Keycloak (localhost:8080) → User authenticates
3. Keycloak redirects browser back with code
4. Application (container) exchanges code for token (keycloak:8080)
5. Application gets user information (keycloak:8080)
```

### Differences: Grafana vs Open WebUI

| Aspect | Grafana | Open WebUI |
|---------|---------|------------|
| **OAuth Type** | Generic OAuth (standard) | OIDC native (proprietary) |
| **Maturity** | High (well-tested) | Medium (less tested) |
| **Configuration** | Simple | Complex |
| **User handling** | Automatic | Requires configuration |
| **Discovery document** | Not needed | Can cause problems |
| **Internal URLs** | Works well | Problems with localhost |

**Why Grafana works better:**
- Generic OAuth is more mature and robust
- Properly handles differences between browser and internal URLs
- Creates users automatically without additional configuration
- Doesn't rely heavily on discovery document

---

## 🔐 Credentials and Access

### Credentials Configuration

**Keycloak Admin Console:**
- URL: http://localhost:8080/admin
- Username: Configured in `.env` as `KEYCLOAK_ADMIN_USER`
- Password: Configured in `.env` as `KEYCLOAK_ADMIN_PASSWORD`

⚠️ **IMPORTANT**: Never use default credentials. Configure secure values in your `.env` file before starting services.

### How to Access Keycloak

1. **Ensure Keycloak is running**:
   ```bash
   docker compose --profile security ps keycloak
   ```

2. **Access admin console**:
   - URL: http://localhost:8080/admin
   - Or directly: http://localhost:8080

3. **Log in with your configured credentials**:
   - Username: Value of `KEYCLOAK_ADMIN_USER` from your `.env`
   - Password: Value of `KEYCLOAK_ADMIN_PASSWORD` from your `.env`

### Changing Credentials

**Option 1: Change from docker-compose.yml**
1. Edit `docker-compose.yml` and modify:
   ```yaml
   environment:
     - KEYCLOAK_ADMIN=your_new_username
     - KEYCLOAK_ADMIN_PASSWORD=your_secure_password
   ```
2. Restart Keycloak:
   ```bash
   docker compose --profile security restart keycloak
   ```

**Option 2: Change from Keycloak UI**
1. Access http://localhost:8080/admin
2. Login with your configured credentials (from `.env`)
3. Go to: **Administration Console** → **User** (top right)
4. Select `admin` user
5. Go to **Credentials** tab
6. Set new password
7. Uncheck "Temporary" if you want it permanent

### If You Forgot Credentials

**Method 1: Check docker-compose.yml**
```bash
grep KEYCLOAK_ADMIN docker-compose.yml
```

**Method 2: Completely Reset Keycloak**
⚠️ **WARNING**: This will delete all Keycloak data.

```bash
# Stop Keycloak
docker compose --profile security stop keycloak

# Remove data volume
docker volume rm my-selfhosted-ai-kit_keycloak_data

# Start Keycloak again
docker compose --profile security up -d keycloak

# Wait 30-60 seconds and access with credentials from .env
```

---

## 🔗 Service Integrations

## ✅ Grafana + Keycloak

### Status: Complete and Working

Grafana has excellent OAuth/OIDC support and works perfectly with Keycloak.

### Configuration

**Variables in docker-compose.yml:**
```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Keycloak
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
  - GF_AUTH_GENERIC_OAUTH_API_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
  - GF_AUTH_SIGNOUT_REDIRECT_URL=http://localhost:8080/realms/master/protocol/openid-connect/logout
  - GF_AUTH_DISABLE_LOGIN_FORM=true
```

**⚠️ IMPORTANT - Client Configuration in Keycloak:**

**About Grafana official documentation:**
[Grafana official documentation](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/keycloak/) recommends that `roles` be in **"Default Client Scopes"** to allow role mapping using `role_attribute_path`. However, in our specific case, this configuration caused the "cannot remove last organization admin" error because the `admin` user in Keycloak has realm roles that Grafana tried to sync.

**Our configuration (specific solution for our case):**
- **`fullScopeAllowed` must be `false`** (NOT `true`)
- The `roles` scope must be in **"Optional"** (NOT in "Default")
- This prevents Keycloak from returning roles automatically
- Grafana won't receive roles and won't try to sync them
- This prevents the "cannot remove last organization admin" error
- Combined with `SKIP_ORG_ROLE_SYNC=true` in Grafana, provides an additional protection layer

**Client in Keycloak:**
- Client ID: `grafana`
- Client authentication: On (confidential)
- Standard flow: Enabled
- **`fullScopeAllowed`: `false`** (CRITICAL)
- Valid redirect URIs: `http://localhost:3001/login/generic_oauth`
- Web origins: `http://localhost:3001`
- Client scopes: `roles` in **Optional** (not Default)

### Setup Steps

1. **Use automated setup** (recommended):
   ```bash
   ./scripts/stack-manager.sh start security monitoring
   ```
   The `keycloak-init` service will automatically create OIDC clients and update secrets in `.env`.

2. **Recreate Grafana** (if manual changes):
   ```bash
   docker compose --profile monitoring up -d --force-recreate grafana
   ```

### How to Use

1. Open Grafana: http://localhost:3001
2. Click "Sign in with Keycloak"
3. Enter your Keycloak credentials (configured in `.env`)
4. You'll be redirected back to Grafana authenticated

⚠️ **IMPORTANT**: Use **Keycloak** credentials, not Grafana. Grafana doesn't accept direct credentials when OAuth is enabled.

---

## ✅ Open WebUI + Keycloak

### Status: Complete - Emulated OIDC Environment

**Solution Implemented:**
Open WebUI integration was solved using an "Emulated OIDC Environment" approach that works around Docker split-horizon networking limitations.

**Problems Solved:**
1. **Split Horizon Routing**: Solved with "Fake Discovery" (`oidc-config.json`) that separates browser routes (`localhost:8080`) and backend (`keycloak:8080`)
2. **UserInfo 401 Errors**: Solved with "Fake UserInfo" (`userinfo.json`) serving static profile data
3. **User Mapping**: Resolved by direct SQLite modification to link OIDC login with existing admin account
4. **Result**: Fully functional SSO authentication with admin@admin-user

### Configuration

**Variables in docker-compose.yml:**
```yaml
environment:
  - ENABLE_OAUTH_SSO=${OPEN_WEBUI_ENABLE_OAUTH_SSO:-true}
  - ENABLE_OAUTH_SIGNUP=${OPEN_WEBUI_ENABLE_OAUTH_SIGNUP:-true}
  - OAUTH_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID:-open-webui}
  - OAUTH_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}
  - OAUTH_PROVIDER_NAME=${OPEN_WEBUI_OAUTH_PROVIDER_NAME:-Keycloak}
  - OPENID_PROVIDER_URL=http://127.0.0.1:8080/static/oidc-config.json
  - OPENID_REDIRECT_URI=${OPEN_WEBUI_URL_PUBLIC:-http://localhost:3000}/oauth/oidc/callback
volumes:
  - ./oidc-config.json:/app/backend/static/oidc-config.json:ro
  - ./userinfo.json:/app/backend/static/userinfo.json:ro
```

**Client in Keycloak:**
- Client ID: `open-webui`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Valid redirect URIs: `http://localhost:3000/oauth/oidc/callback`
- Web origins: `http://localhost:3000`

### Architecture

The solution uses two static JSON files served by Open WebUI itself:

1. **`oidc-config.json`**: Fake OIDC discovery document with split routing
2. **`userinfo.json`**: Fake UserInfo endpoint returning static profile data

This works around Open WebUI's limitation that it cannot handle different URLs for browser (localhost) vs backend (keycloak) when using discovery documents.

---

## ⏳ n8n + Keycloak

### Status: Configured - Pending Testing

n8n has better OIDC support than Open WebUI and should work correctly, similar to Grafana.

### Configuration

**Variables in docker-compose.yml:**
```yaml
environment:
  - N8N_AUTH_TYPE=oidc
  - N8N_OIDC_ISSUER=http://localhost:8080/realms/master
  - N8N_OIDC_CLIENT_ID=n8n
  - N8N_OIDC_CLIENT_SECRET=${N8N_OIDC_CLIENT_SECRET}
  - N8N_OIDC_AUTHORIZATION_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
  - N8N_OIDC_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
  - N8N_OIDC_USER_INFO_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
  - N8N_OIDC_REDIRECT_URI=http://localhost:5678/rest/oauth2-credential/callback
  - N8N_OIDC_SCOPES=openid profile email
```

**Client in Keycloak:**
- Client ID: `n8n`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Valid redirect URIs: `http://localhost:5678/rest/oauth2-credential/callback`
- Web origins: `http://localhost:5678`

### Setup Steps

**Automated (Recommended):**
```bash
./scripts/stack-manager.sh start security automation
```

The `keycloak-init` service will create clients and update secrets automatically.

---

## ✅ Jenkins + Keycloak

### Status: Configured - Ready to Use

Jenkins is configured to use Keycloak as OIDC provider via the "OpenId Connect Authentication" plugin.

### Automatic Configuration

Jenkins OIDC is configured **automatically** via Groovy init scripts:
- `config/jenkins/init.groovy.d/02-auth-oidc.groovy` - Configures OIDC authentication
- `keycloak-init` service creates the Jenkins client in Keycloak

### Setup Steps

**Automated (Recommended):**
```bash
# 1. Start services (keycloak-init creates clients automatically):
./scripts/stack-manager.sh start security ci-cd

# 2. Verify clients were created in Keycloak admin console

# 3. Test login at http://localhost:8081 - click "Log in with Keycloak"
```

**Client in Keycloak:**
- Client ID: `jenkins`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Valid redirect URIs: `http://localhost:8081/securityRealm/finishLogin`
- Web origins: `http://localhost:8081`
- fullScopeAllowed: false

> ⚠️ **Important**: The redirect URI (`/securityRealm/finishLogin`) is a callback endpoint that should NOT be accessed directly. The correct flow is:
> 1. Go to `http://localhost:8081`
> 2. Click "Log in with Keycloak"
> 3. Authenticate in Keycloak
> 4. Keycloak automatically redirects to the callback URL with the required `state` parameter

---

## 🔍 Troubleshooting

### Common Problems

**1. Error: "Invalid redirect URI"**
- Verify Redirect URI in Keycloak exactly matches application configuration
- Include protocol (`http://`), host (`localhost`), port and complete path
- No spaces, no trailing slash

**2. Error: "Client authentication failed"**
- Verify Client Secret in Keycloak matches application configuration
- Verify client has "Client authentication: On" if confidential

**3. Error: "Connection refused" when getting token**
- Verify Keycloak is running
- Verify application is in same Docker network as Keycloak
- Verify token/userinfo URLs use `keycloak:8080` (not `localhost:8080`)

**4. Error: "State cannot be determined" (Jenkins)**
- This error occurs when navigating directly to `/securityRealm/finishLogin`
- The callback URL requires a `state` parameter from the OIDC flow
- **Solution**: Start the login flow from `http://localhost:8081` → click "Log in with Keycloak"

**5. Error: "ERR_CONNECTION_REFUSED" in browser**
- Verify Keycloak is running
- Verify authorization/logout URLs use `localhost:8080` (not `keycloak:8080`)

**5. Error: "Login provider denied login request"**
- Clear Keycloak cookies from browser (use incognito window)
- Restart Keycloak to clear sessions
- Verify user exists in Keycloak

### Clean Sessions

If there are session problems:
1. **Use incognito window** (easiest)
2. Or manually clear cookies: F12 → Application → Cookies → `http://localhost:8080`
3. Or restart Keycloak: `docker compose --profile security restart keycloak`

---

## 🛠️ Database Issues

### Automatic Fix

Database issues are now **automatically and transparently** fixed.

**What it does automatically:**

When you run `./scripts/stack-manager.sh start` with `security` profile, the system:

1. **Automatically verifies** if there are problems in Keycloak database
2. **Automatically fixes** any problems found:
   - Pending transactions
   - Old locks in `databasechangeloglock`
   - Orphaned connections
3. **Reports** what was fixed (only if it fixed something)
4. **Continues** starting Keycloak normally

### Why Database Problems Occur

**Common causes:**

1. **System restart** - Docker stops abruptly, Keycloak doesn't have time to close connections
2. **`docker compose down` or `stop`** - Sometimes Docker stops containers too fast
3. **Network problems** - Connection drops but PostgreSQL doesn't realize immediately
4. **Out of memory (OOM)** - Linux can kill processes (OOM Killer)
5. **Keycloak crashes** - Dies without closing connections cleanly

### What are "Pending Transactions"?

When Keycloak performs a database operation:

1. **Opens transaction**: `BEGIN`
2. **Makes changes**: INSERT, UPDATE, DELETE
3. **Closes transaction**: `COMMIT` or `ROLLBACK`

**The problem**: If Keycloak stops between step 1 and 3, the transaction remains open.

PostgreSQL thinks: "This connection is in the middle of a transaction, I must wait for it to finish"

But Keycloak no longer exists, so the transaction never finishes.

### Manual Diagnosis (Optional)

For detailed diagnosis:

```bash
# Detailed diagnosis with manual cleanup option
./scripts/stack-manager.sh diagnose keycloak-db
```

This shows detailed information about connections, transactions and locks, and allows you to decide whether to clean manually.

### Safety

**YES, it's completely safe** because:

1. **Only terminates "dead" connections** - Doesn't touch active connections
2. **Only terminates "hung" transactions** - Only those in `idle in transaction` state
3. **Doesn't modify data** - Only closes connections, doesn't execute `DELETE`, `DROP`, or anything destructive

### Prevention

Improvements in `docker-compose.yml` help prevent the problem:

1. **`stop_grace_period: 30s`** - Gives 30 seconds to Keycloak to cleanly close connections
2. **`idle_in_transaction_session_timeout=60000`** - If a transaction is idle for more than 60 seconds, PostgreSQL automatically terminates it
3. **Connection pool configured** - Keycloak manages connections better

---

## 📚 References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Grafana OAuth Documentation](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/)
- [n8n OAuth Documentation](https://docs.n8n.io/hosting/authentication/oauth/)
- [Open WebUI GitHub Issues](https://github.com/open-webui/open-webui/issues)

---

**Last updated**: 2026-01-25

---

## 🔐 Automated Role Mapping

The system implements an **Automated Role Mapping** strategy to ensure that Keycloak roles are correctly translated into application permissions (Admin, Editor, Viewer) without manual configuration in the GUIs.

### How it works

1.  **Creation (`auth-manager.sh`)**:
    *   Creates roles in Keycloak (e.g., `grafana-admin`, `openwebui-admin`).
    *   Creates a **Client Role Mapper** that adds these roles to the Access Token under the top-level `roles` claim.

2.  **Consumption (`docker-compose.yml`)**:
    *   Applications are configured to "read" this specific claim and map it to their internal permission levels.

### Specific Implementations

#### Grafana (JMESPath)
Grafana uses **JMESPath** to parse the JSON Token and decide the user's role.
*   **Variable**: `GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH`
*   **Logic**:
    ```javascript
    contains(roles[*], 'grafana-admin') && 'Admin' || 
    contains(roles[*], 'grafana-editor') && 'Editor' || 'Viewer'
    ```
    *   If token has `grafana-admin` → User becomes **Admin** in Grafana.
    *   If token has `grafana-editor` → User becomes **Editor**.
    *   Otherwise → **Viewer**.

#### Open WebUI (Claim Mapping)
Open WebUI looks for a specific list of roles in the token.
*   **Variable**: `OPENID_ROLES_CLAIM=roles` (Configured to look at the top-level 'roles' claim)
*   **Variable**: `OPENID_ADMIN_ROLE=openwebui-admin`
    *   If the user has the role `openwebui-admin`, they are automatically promoted to **Admin**.
*   **Variable**: `DEFAULT_USER_ROLE=user`
    *   Ensures new users are activated automatically (avoids "Pending" state).

### ✅ Automated Verification
We have dedicated tests to ensure this "Contract" is never broken:
1.  **`scripts/tests/test-roles-mapping.sh`**: Static analysis that ensures `docker-compose.yml` contains the correct mapping rules.
2.  **`scripts/tests/test-keycloak-claims.sh`**: Integration test that logs in, decodes a real token, and verifies that Keycloak is actually sending the roles.

---

## n8n + Keycloak

### ⚠️ Licensing Limitation (Community Edition)

**Current Status**: disabled in `.env`.

The integration of OIDC (SSO) in n8n is an **Enterprise** feature. The Community Edition (free) installed in this stack **does not support** logging in with Keycloak, surfacing the error:
`[license SDK] Skipping renewal on init: license cert is not initialized`

### Enabling OIDC (If License Purchased)

If you upgrade to a paid n8n license in the future, follow these steps to enable SSO:

1. **Uncomment Configuration**:
   Edit `.env` and uncomment the `N8N_AUTH_TYPE=oidc` line:
   ```bash
   # .env
   N8N_AUTH_TYPE=oidc
   N8N_OIDC_CLIENT_ID=n8n
   # ... other variables are already set correctly ...
   ```

2. **Restart n8n**:
   ```bash
   docker compose restart n8n
   ```

3. **Verify**:
   The login screen will now show a "Sign in with Keycloak" button.

### Current Authentication Method
For now, default to **Email/Password** authentication.
- **URL**: http://localhost:5678
- **User**: Setup the owner account on first login.

---

## Jenkins + Keycloak

### ✅ Fully Automated Support
Jenkins integration is now **100% automated** in this stack.
- **Admin**: Created automatically (user: `admin`, pass: from `.env`).
- **Setup Wizard**: Disabled automatically.
- **OIDC**: Configured automatically via `init.groovy.d/02-auth-oidc.groovy`.
- **Plugin**: `oic-auth` installed.

### Access
1.  **URL**: http://localhost:8081
2.  **Login**: Click **"Log in with Keycloak"** (uses your Keycloak credentials from `.env`).
3.  **Role**: The first user logged in via OIDC usually gets Create permission, or Admin if configured strategies allow. The `02-auth-oidc.groovy` script sets `FullControlOnceLoggedInAuthorizationStrategy`, meaning **any valid Keycloak user becomes an Admin**.
    *   *Security Note*: For production, you should refine the `AuthorizationStrategy` in `config/jenkins/init.groovy.d/02-auth-oidc.groovy`.
