# Implementation Readiness Assessment Report

**Date:** 2026-02-02
**Project:** lurus-webmail

---

## 1. Document Alignment Check / 文档对齐检查

| Document | Status | Notes |
|----------|--------|-------|
| Product Brief | Complete | Vision, users, scope clearly defined |
| PRD | Complete | 6 FR groups, 5 NFR groups, release plan |
| Architecture | Complete | Component diagram, ADRs, deployment |
| Epics & Stories | Complete | 5 epics, 16 stories |
| UX Design | Skipped | Upstream UI used as-is, customization minimal |

**Alignment Score: 4/5** - UX skipped intentionally (upstream fork).

---

## 2. Prerequisite Checklist / 前置条件检查

### Infrastructure ✅

| Item | Status | Detail |
|------|--------|--------|
| K3s Cluster | ✅ Ready | 4 nodes operational |
| PostgreSQL (CNPG) | ✅ Ready | lurus-pg-rw running |
| ArgoCD | ✅ Ready | Syncing from GitHub via debian node |
| GitHub Actions | ✅ Ready | CI/CD pipeline functional |
| Traefik Ingress | ✅ Ready | HTTPS + TCP routing configured |
| DNS | ✅ Ready | mail.lurus.cn → 43.226.46.164 |

### Services ✅ (with gaps)

| Item | Status | Detail |
|------|--------|--------|
| Stalwart | ✅ Deployed | mail namespace, needs admin password |
| Redis | ✅ Running | lurus-webmail namespace |
| Typesense | ✅ Running | lurus-webmail namespace |
| Supabase Stack | ✅ Running | PostgREST + Auth |
| webmail-web | ✅ Running | v1.1.11 |
| webmail-worker | ✅ Running | v1.1.11 |

### Configuration ⚠️ (Blockers)

| Item | Status | Blocker? |
|------|--------|----------|
| Zitadel Client ID/Secret | ❌ TODO | **Yes** - SSO non-functional |
| SendCloud API Credentials | ❌ TODO | **Yes** - China relay non-functional |
| Stalwart Admin Password | ❌ TODO | **Yes** - Insecure default |
| DKIM Key | ⚠️ Unchecked | Needs verification |
| JWT Secret | ✅ Configured | 32+ chars |
| Supabase Keys | ✅ Configured | Correctly signed |

---

## 3. Blocker Summary / 阻塞问题

### Critical (Must Fix Before Use)

| # | Blocker | Epic | Story | Effort |
|---|---------|------|-------|--------|
| B1 | Zitadel OIDC not configured | Epic 2 | 2.1 | Config task |
| B2 | SendCloud credentials missing | Epic 1 | 1.2 | Config task |
| B3 | Stalwart admin password default | Epic 2 | 2.2 | Config task |

### Important (Should Fix Soon)

| # | Issue | Epic | Story |
|---|-------|------|-------|
| I1 | kurrier naming throughout codebase | Epic 5 | 5.1 |
| I2 | K3s cross-node DNS workaround | Epic 5 | 5.3 |
| I3 | No monitoring dashboard | Epic 5 | 5.2 |
| I4 | No backup verification | Epic 5 | 5.4 |

---

## 4. Recommended Sprint Order / 建议迭代顺序

### Sprint 1: Unblock Core Functionality (Epic 2 + Epic 1 partial)
- Story 2.1: Configure Zitadel OIDC Client
- Story 2.2: Configure Stalwart Admin Password
- Story 2.3: Audit and replace all TODO secrets
- Story 1.2: Configure SendCloud Relay
- Story 1.3: Verify DKIM/SPF/DMARC

### Sprint 2: Validate & Stabilize (Epic 1 remainder)
- Story 1.1: Validate IMAP IDLE real-time sync
- Story 5.2: Set up monitoring dashboard
- Story 5.4: Set up automated backup

### Sprint 3: Calendar & Contacts (Epic 3)
- Story 3.1: Verify CalDAV sync (iOS)
- Story 3.2: Verify CardDAV sync (iOS)
- Story 3.3: Calendar Web UI

### Sprint 4: Tech Debt (Epic 5 remainder)
- Story 5.1: Rename kurrier references
- Story 5.3: Resolve cross-node DNS

### Sprint 5: API (Epic 4)
- Story 4.1: Design Mail API spec
- Story 4.2: Implement Mail Send API
- Story 4.3: Implement Webhook callbacks

---

## 5. Readiness Verdict / 就绪判定

### Overall: ⚠️ CONDITIONALLY READY

**可以开始 Sprint 1**，但有 3 个 Critical Blockers 需要在正式使用前解决（均为配置任务，不涉及代码变更）。

核心代码（邮件收发、Web UI、IMAP IDLE）已经部署并运行。主要差距在于凭据配置和安全加固。

### Recommended Immediate Actions

1. 登录 https://auth.lurus.cn 创建 lurus-webmail OIDC Application
2. 获取 SendCloud API User/Key 并填入 secrets
3. 设置 Stalwart admin 安全密码
4. 运行 `kustomize build k8s/ | kubectl apply -f -` 验证配置完整性
