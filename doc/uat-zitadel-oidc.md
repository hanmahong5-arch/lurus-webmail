# UAT Plan: Zitadel OIDC for lurus-webmail

> Date: 2026-03-02
> Scope: Verify SSO login via Zitadel works end-to-end on mail.lurus.cn

---

## 0. Prerequisite Fixes (Blockers)

Must resolve before testing. All are infra issues, not code issues.

### P1: Master node disk space (CRITICAL)

`cloud-ubuntu-1-16c32g` at 92% disk (`/data`), kubelet evicting pods.

```bash
ssh root@100.98.57.55
# Check disk usage
du -sh /data/agent/containerd/io.containerd.snapshotter.v1.overlayfs/* | sort -rh | head -20
# Prune unused container images
crictl rmi --prune
# Prune containerd snapshots
ctr -n k8s.io content ls | wc -l
# If still tight, remove old containerd snapshots
```

**Pass criteria**: `df -h /data` shows < 80% usage, no `EvictionThresholdMet` events.

### P2: GoTrue DB connectivity from office-wsl-1

GoTrue hangs at startup because it can't reach `lurus-pg-rw` (10.43.9.14:5432) from the WSL node.

**Option A** (preferred): Fix disk on master → GoTrue auto-schedules to master.
**Option B**: Debug K3s ClusterIP routing from office-wsl-1:

```bash
# From office-wsl-1 WSL shell
sudo iptables -t nat -L KUBE-SERVICES | grep 10.43.9.14
# If missing, restart k3s-agent
sudo systemctl restart k3s-agent
```

**Pass criteria**: GoTrue pod shows `1/1 Running`, `curl mail.lurus.cn/api/kong/auth/v1/settings | grep keycloak` returns `true`.

### P3: Frontend rebuild with provider change

Code changed `signInWithOAuth("zitadel")` → `signInWithOAuth("keycloak")` but image not rebuilt.

```bash
cd C:\Users\Anita\Desktop\lurus\lurus-webmail

# Build
docker build -f apps/web/Dockerfile -t ghcr.io/hanmahong5-arch/lurus-webmail-web:latest .
docker push ghcr.io/hanmahong5-arch/lurus-webmail-web:latest

# Deploy
ssh root@100.98.57.55 "kubectl rollout restart deployment/webmail-web -n lurus-webmail"
```

**Pass criteria**: `webmail-web` pod restarts with new image, login page loads.

---

## 1. Component Health Checks

Run BEFORE functional tests. All must pass.

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1.1 | GoTrue alive | `curl -s mail.lurus.cn/api/kong/auth/v1/health` | `{"status":"ok"}` |
| 1.2 | Keycloak provider on | `curl -s mail.lurus.cn/api/kong/auth/v1/settings \| jq .external.keycloak` | `true` |
| 1.3 | OIDC Proxy alive | `kubectl get pods -n lurus-identity -l app=oidc-proxy` | `1/1 Running` |
| 1.4 | Auth path rewrite | `curl -sI 'auth.lurus.cn/protocol/openid-connect/auth?client_id=361997337561728841@lurus-api&response_type=code&scope=profile+email&redirect_uri=https://mail.lurus.cn/api/kong/auth/v1/callback'` | `302 → /ui/login/login?authRequestID=...` |
| 1.5 | Zitadel healthy | `curl -s auth.lurus.cn/.well-known/openid-configuration \| jq .issuer` | `"https://auth.lurus.cn"` |
| 1.6 | Web frontend loads | `curl -sI mail.lurus.cn` | `200 OK` |

---

## 2. Functional Tests

### T1: SSO Login — Happy Path

**Precondition**: User `xiaohan1105@163.com` exists in Zitadel (active).

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open `https://mail.lurus.cn/auth/login` in browser | Login page with "Login with Lurus Account" button |
| 2 | Click "Login with Lurus Account" | Redirect to `auth.lurus.cn` login page |
| 3 | Enter `xiaohan1105@163.com` + password | Zitadel accepts credentials |
| 4 | Zitadel redirects back | Browser goes to `mail.lurus.cn/auth/callback?code=...` |
| 5 | Callback processes | Redirect to `/dashboard` or `/dashboard/platform/overview` |
| 6 | Check session | User is authenticated, dashboard loads |

**Pass**: Steps 1-6 complete without errors, user lands on dashboard.

### T2: SSO Login — Admin User

Same flow as T1, using `zitadel-admin@zitadel.auth.lurus.cn` / `Lurus@ops`.

**Pass**: Login succeeds, user reaches dashboard.

### T3: SSO Logout

| Step | Action | Expected |
|------|--------|----------|
| 1 | While logged in, click logout/sign-out | Session cleared |
| 2 | Try accessing `/dashboard` | Redirect to `/auth/login` |
| 3 | Verify Zitadel session ended | Re-visiting `auth.lurus.cn` shows login form (not auto-login) |

**Pass**: Session fully invalidated, requires re-authentication.

### T4: Invalid/Cancelled Login

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "Login with Lurus Account" | Redirect to Zitadel |
| 2 | Enter wrong password | Zitadel shows "Invalid credentials" error |
| 3 | Click back / close tab | No crash, can retry |

**Pass**: Error handled gracefully, no blank screen or 500 error.

### T5: Token Refresh (Optional)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login successfully | Session active |
| 2 | Wait > 1 hour (JWT_EXPIRY=3600) | Token expires |
| 3 | Interact with dashboard | Session auto-refreshes OR prompts re-login |

**Pass**: No unexpected logout or crash.

---

## 3. API-Level Verification (curl)

Can run without browser; useful for CI or quick validation.

```bash
# T-API-1: GoTrue → proxy → Zitadel redirect chain
RESPONSE=$(curl -s -D - -o /dev/null \
  "https://mail.lurus.cn/api/kong/auth/v1/authorize?provider=keycloak")
echo "$RESPONSE" | grep "302"       # GoTrue redirects
echo "$RESPONSE" | grep "auth.lurus.cn/protocol/openid-connect"  # points to Zitadel

# T-API-2: Proxy rewrites to Zitadel and adds openid scope
REDIRECT_URL=$(echo "$RESPONSE" | grep -oP 'location: \K.*' | tr -d '\r')
ZITADEL_RESPONSE=$(curl -s -D - -o /dev/null "$REDIRECT_URL")
echo "$ZITADEL_RESPONSE" | grep "302"          # Zitadel redirects to login
echo "$ZITADEL_RESPONSE" | grep "authRequestID" # valid auth request

# T-API-3: Token endpoint accessible
curl -s -X POST "https://auth.lurus.cn/protocol/openid-connect/token" \
  -d "grant_type=authorization_code&code=invalid" 2>&1 | grep -v "404"
# Should return 400 (bad code), NOT 404 (path not found)

# T-API-4: Userinfo endpoint accessible
curl -s "https://auth.lurus.cn/protocol/openid-connect/userinfo" 2>&1 | head -1
# Should return 401 (no token), NOT 404
```

---

## 4. Negative / Edge Cases

| # | Scenario | Expected |
|---|----------|----------|
| N1 | Access `?provider=zitadel` (old name) | `400 Unsupported provider` (acceptable, not a crash) |
| N2 | Direct access to `/auth/callback` without code | Error page, not 500 |
| N3 | Tampered state parameter | GoTrue rejects, shows error |
| N4 | Locked Zitadel user (`maravin.uu@gmail.com`) tries login | Zitadel denies, user sees error |

---

## 5. Sign-off

| Criterion | Status |
|-----------|--------|
| P1-P3 prerequisites resolved | [ ] |
| 1.1-1.6 health checks pass | [ ] |
| T1 Happy path login works | [ ] |
| T3 Logout works | [ ] |
| T4 Error handling graceful | [ ] |
| N1-N4 edge cases don't crash | [ ] |

**UAT approved by**: _________________ **Date**: _________
