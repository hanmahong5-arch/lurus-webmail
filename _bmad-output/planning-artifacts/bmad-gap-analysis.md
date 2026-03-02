---
date: 2026-02-27
version: 2.0
author: Anita (via BMAD Gap Analysis)
framework: BMAD v6
scope: lurus-webmail v2.0 renovation readiness assessment
supersedes: bmad-gap-analysis.md v1.0 (2026-02-02, platform-wide)
---

# lurus-webmail v2.0 — Renovation Readiness Assessment
# lurus-webmail v2.0 — 改造准备度评估

---

## Executive Summary / 执行摘要

对 lurus-webmail 从 Kurrier fork 改造为 Stalwart-Native 架构的准备度评估。评估基于 6 个维度：基础设施就绪度、代码库可改造性、依赖项风险、团队能力、迁移复杂度、回退安全性。

### Overall Readiness Score / 整体准备度评分

| Dimension | Score | Grade | Notes |
|-----------|-------|-------|-------|
| Infrastructure Readiness | 85/100 | A- | Stalwart, NATS, Redis 已就位 |
| Codebase Malleability | 60/100 | C+ | Supabase 深度耦合需大量替换 |
| Dependency Risk | 70/100 | B | jmap-jam 新但可控，Stalwart 成熟 |
| Team Capability | 80/100 | B+ | TypeScript 熟练，JMAP 需学习 |
| Migration Complexity | 55/100 | C | Auth + data migration 同时进行有风险 |
| Rollback Safety | 75/100 | B | Feature flag 策略可保证回退 |
| **Overall** | **71/100** | **B-** | **可以启动，需注意 Phase 1-2 风险** |

---

## 1. Infrastructure Readiness / 基础设施就绪度

### Already Running / 已就绪

| Component | Status | Location | Ready for v2.0? |
|-----------|--------|----------|-----------------|
| Stalwart Mail Server | Running | mail namespace | Yes — JMAP endpoint at :8080 |
| PostgreSQL (CNPG) | Running | database namespace | Yes — schema: webmail |
| Redis | Running | lurus-webmail namespace | Yes — BullMQ queues |
| NATS | Running | messaging node | Yes — need create WEBMAIL_EVENTS stream |
| Zitadel | Running | auth.lurus.cn | Yes — need create OIDC app |
| Traefik | Running | kube-system | Yes — ingress routes need update |
| ArgoCD | Running | argocd namespace | Yes — no change needed |
| Grafana/Prometheus | Running | monitoring | Yes — add webmail dashboard |

### Needs Configuration / 需要配置

| Item | Effort | Blocker? |
|------|--------|----------|
| Stalwart OIDC → Zitadel | 2h | Yes (Epic 0 blocker) |
| Zitadel OIDC app for webmail | 1h | Yes (Epic 0 blocker) |
| SendCloud credentials | 1h | No (degraded: all via Stalwart) |
| NATS WEBMAIL_EVENTS stream | 30min | No (Epic 4) |
| Stalwart admin password | 30min | No (security hardening) |
| DMARC upgrade to p=reject | 1h + 1week monitoring | No (gradual) |

### Not Available / 缺失

| Item | Impact | Mitigation |
|------|--------|------------|
| Stalwart backup automation | High | Add RocksDB snapshot to MinIO cron |
| Web Push VAPID keys | Low | Generate during Epic 3 |
| OTel Collector | Low | Deploy during Epic 5 |

---

## 2. Codebase Analysis / 代码库分析

### Supabase Coupling Points / Supabase 耦合点

| Location | Type | Replacement Effort |
|----------|------|-------------------|
| `packages/api-client/` | Supabase JS client wrapper | High — full rewrite to fetch + JWT |
| `apps/web/app/auth/` | Supabase Auth flows | High — rewrite to Zitadel OIDC |
| `apps/web/next.config.ts` | `/api/kong/*` rewrites | Low — remove rewrite rules |
| `apps/worker/lib/api-helpers.ts` | Supabase auth verification | Medium — replace with JWT verify |
| `packages/db/` | Drizzle ORM (PostgreSQL) | Low — keep, reduce table scope |
| `k8s/supabase.yaml` | Kong, GoTrue deployments | Low — delete manifests |

**Total Supabase replacement: ~40 files, estimated 3-5 days of focused work.**

### IMAP Code to Deprecate / IMAP 代码待废弃

| Directory | Lines (est.) | Purpose | Replaced By |
|-----------|-------------|---------|-------------|
| `apps/worker/lib/imap/` | ~2,000 | IMAP sync, IDLE, delta-fetch | JMAP client |
| `apps/worker/server/plugins/smtp-worker.ts` | ~300 | IMAP sync jobs | JMAP push events |
| `apps/worker/server/plugins/common-worker.ts` | ~200 | Sync-related jobs | Reduced scope |

**Total IMAP code to remove: ~2,500 lines**

### Code to Keep / 保留的代码

| Directory | Purpose | Changes Needed |
|-----------|---------|---------------|
| `apps/web/app/dashboard/` | Mail/Calendar/Contacts UI | Data source: PG → JMAP |
| `apps/worker/lib/smtp/router.ts` | China/International routing | Keep, minor refactor |
| `apps/worker/lib/admin/stalwart-api.ts` | Stalwart Admin API client | Keep, extend |
| `packages/db/` | Drizzle ORM + migrations | Reduce to metadata tables |
| `packages/schema/` | Zod validation | Keep |
| `packages/ui/` | React UI components | Keep |
| `packages/core/` | Business logic | Keep |

### New Code Required / 需要新写的代码

| Component | Lines (est.) | Epic |
|-----------|-------------|------|
| JMAP client layer (jmap-jam wrapper) | ~500 | Epic 2 |
| JMAP API proxy routes | ~300 | Epic 2 |
| Zitadel OIDC auth (Next.js) | ~400 | Epic 1 |
| JWT middleware + RLS helper | ~200 | Epic 1 |
| AI feature endpoints | ~600 | Epic 3 |
| PWA Service Worker + Web Push | ~400 | Epic 3 |
| NATS event publisher | ~200 | Epic 4 |
| Sieve rule compiler | ~300 | Epic 4 |
| OTel instrumentation | ~300 | Epic 5 |

**Total new code: ~3,200 lines**

---

## 3. Dependency Risk Assessment / 依赖项风险评估

### Critical Dependencies / 关键依赖

| Dependency | Risk | Maturity | Mitigation |
|------------|------|----------|------------|
| **Stalwart JMAP** | Medium | High (Rust, security audited) | Pin version; E2E test JMAP flows |
| **jmap-jam** | Medium | Low (73 stars, active) | Small codebase (~2KB), forkable; evaluate jmap-yacl as alternative |
| **Zitadel OIDC** | Low | High (production at auth.lurus.cn) | Already in use by other services |
| **Drizzle ORM** | Low | High (v0.44, widely used) | No change from v1.0 |
| **BullMQ** | Low | High (v5.61, mature) | No change from v1.0 |
| **NATS** | Low | High (production at messaging node) | Already in use by lurus-identity |

### jmap-jam Library Evaluation / jmap-jam 库评估

| Criteria | Assessment |
|----------|-----------|
| Bundle size | ~2KB gzipped — excellent |
| TypeScript support | Strong typing, zero-dep |
| API coverage | JMAP Core + Mail — sufficient |
| Active maintenance | Last update Jan 2026 |
| Production usage | Unknown (73 stars) |
| Risk mitigation | Small codebase, easy to fork/patch |

**Recommendation:** Start with jmap-jam. If issues arise, switch to jmap-yacl (tested against Stalwart). Both are small enough to fork.

---

## 4. Migration Risk Matrix / 迁移风险矩阵

| Risk | Phase | Severity | Likelihood | Mitigation |
|------|-------|----------|-----------|------------|
| Supabase removal breaks all UI data access | Epic 1 | Critical | High | Map ALL Supabase calls first; replace one-by-one; feature flag |
| JMAP responses differ from PostgreSQL schema | Epic 2 | High | Medium | Build adapter layer; normalize JMAP data to match current UI props |
| Stalwart OIDC token flow incompatible | Epic 0 | High | Low | Test in isolation first; fallback to basic auth |
| PostgreSQL mail data not in Stalwart | Epic 2 | Medium | Low | Data already synced via IMAP; Stalwart has authoritative copy |
| SendCloud credentials unavailable | Epic 0 | Medium | Medium | All mail routes through Stalwart direct (lower China deliverability) |
| JMAP push unreliable | Epic 2 | Low | Medium | Polling fallback (30s); Web Push as secondary channel |
| AI latency too high for UX | Epic 3 | Low | Low | All AI async; never block mail operations |

### Critical Path / 关键路径

```
Epic 0 (Foundation)
  └─ Story 0.3 (Stalwart OIDC) ← BLOCKER for everything
  └─ Story 0.5 (Zitadel app) ← BLOCKER for Epic 1
      └─ Epic 1 (Auth Overhaul)
          └─ Story 1.1 (Zitadel in Next.js) ← BLOCKER for JMAP auth
          └─ Story 1.4 (Replace Supabase calls) ← HIGHEST EFFORT
              └─ Epic 2 (JMAP Core)
                  └─ Story 2.1 (JMAP client) ← BLOCKER for all JMAP stories
                  └─ Story 2.3 (Inbox migration) ← KEY VALIDATION POINT
```

---

## 5. Rollback Strategy / 回退策略

### Per-Phase Rollback / 每阶段回退方案

| Phase | Rollback Method | Data Loss Risk |
|-------|----------------|---------------|
| Epic 0 (Foundation) | Revert K8s secrets; no code change | None |
| Epic 1 (Auth) | Feature flag: `SUPABASE_DISABLED=false` → old auth path | None |
| Epic 2 (JMAP) | Feature flag: `JMAP_ENABLED=false` → PostgreSQL path | None (dual-read period) |
| Epic 3 (AI/PWA) | Feature flag: `AI_ENABLED=false`, `PWA_ENABLED=false` | None (additive features) |
| Epic 4 (DAV/Rules) | Revert Sieve scripts; re-enable app-layer rules | None |
| Epic 5 (Cleanup) | **No rollback** — only proceed when all prior phases stable | N/A |

### Feature Flag Implementation / 特性开关实现

```typescript
// Controlled via environment variables in K8s ConfigMap
const flags = {
  SUPABASE_DISABLED: process.env.SUPABASE_DISABLED === 'true',
  JMAP_ENABLED: process.env.JMAP_ENABLED === 'true',
  AI_ENABLED: process.env.AI_ENABLED === 'true',
  PWA_ENABLED: process.env.PWA_ENABLED === 'true',
};

// Usage in API routes
if (flags.JMAP_ENABLED) {
  return fetchFromJMAP(mailboxId);
} else {
  return fetchFromPostgreSQL(mailboxId);  // legacy path
}
```

---

## 6. Go-NoGo Checklist / 启动检查清单

### Must Have Before Starting / 启动前必须就绪

| # | Item | Status | Owner |
|---|------|--------|-------|
| 1 | Stalwart JMAP endpoint reachable from lurus-webmail namespace | ⏳ Verify | Anita |
| 2 | Zitadel OIDC application created for mail.lurus.cn | ⏳ Create | Anita |
| 3 | Stalwart OIDC configured with Zitadel | ⏳ Configure | Anita |
| 4 | Full inventory of Supabase client calls (file:line) | ⏳ Audit | AI |
| 5 | jmap-jam library evaluated against Stalwart (basic test) | ⏳ Test | AI |
| 6 | Stalwart backup procedure documented | ⏳ Document | Anita |
| 7 | Current mail data verified in Stalwart (not only in PG) | ⏳ Verify | Anita |

### Nice to Have / 最好有

| # | Item | Status |
|---|------|--------|
| 8 | SendCloud credentials configured | ⏳ |
| 9 | NATS WEBMAIL_EVENTS stream created | ⏳ |
| 10 | Grafana dashboard placeholder created | ⏳ |

---

## 7. Effort Estimation Summary / 工作量估算

| Phase | New Code | Remove Code | Config | Total Effort |
|-------|----------|-------------|--------|-------------|
| Epic 0 | ~100 lines | ~50 lines | Heavy (credentials, DNS) | 2 weeks |
| Epic 1 | ~600 lines | ~1,500 lines (Supabase) | Medium (K8s manifests) | 2 weeks |
| Epic 2 | ~800 lines | ~2,500 lines (IMAP) | Light | 3 weeks |
| Epic 3 | ~1,000 lines | 0 | Medium (VAPID, AI config) | 2 weeks |
| Epic 4 | ~500 lines | ~1,000 lines (DAV) | Light | 2 weeks |
| Epic 5 | ~300 lines | ~500 lines (cleanup) | Medium (OTel, Grafana) | 1 week |
| **Total** | **~3,300 lines** | **~5,550 lines** | — | **~12 weeks** |

**Net code change: -2,250 lines (code reduction)** — This is a good sign. The renovation makes the codebase smaller while adding features.

---

## Conclusion / 结论

**Readiness: GO with caution / 准备就绪，谨慎执行**

核心风险集中在 Epic 0-1（Stalwart OIDC + Supabase 移除），这两个阶段是最大的技术挑战。一旦认证链路打通，后续的 JMAP 迁移和功能添加相对低风险。

**建议执行顺序:**
1. 先完成 Go-NoGo Checklist 的 7 个必要项
2. Epic 0 + Epic 1 紧密衔接，密集执行
3. Epic 2 是核心验证点 — Story 2.3（Inbox 迁移）决定整体迁移可行性
4. Epic 3 和 Epic 4 可以并行
5. Epic 5 仅在前序 Epic 全部稳定后执行
