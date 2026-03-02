---
stepsCompleted: [init, context, decisions, patterns, structure, validate, finalize]
inputDocuments: [prd.md v2.0, product-brief.md v2.0, lurus.yaml, 2026-industry-research]
workflowType: 'architecture'
project_name: 'lurus-webmail'
version: 2.0
date: '2026-02-27'
supersedes: architecture.md v1.0 (2026-02-02)
---

# Architecture Decision Document — lurus-webmail v2.0

## 1. System Overview / 系统概览

### v2.0 "Stalwart-Native" Architecture

```
                           ┌──────────────────────────────────────┐
                           │            Internet / DNS             │
                           │   MX: mail.lurus.cn → 43.226.46.164  │
                           └───────────────┬──────────────────────┘
                                           │
                           ┌───────────────▼──────────────────────┐
                           │   Traefik Ingress (K3s master)        │
                           │   ├─ HTTPS mail.lurus.cn → web:3000   │
                           │   ├─ TCP :25/:465/:587 → stalwart     │
                           │   └─ TCP :993 → stalwart              │
                           └───────────────┬──────────────────────┘
                                           │
              ┌────────────────────────────┼────────────────────────┐
              │                            │                        │
   ┌──────────▼───────────┐   ┌───────────▼──────────┐   ┌────────▼──────────┐
   │  ns: lurus-webmail    │   │  ns: mail             │   │  ns: database      │
   │                       │   │                       │   │                    │
   │  ┌─────────────────┐  │   │  Stalwart Mail Server │   │  lurus-pg-rw:5432  │
   │  │ webmail-web:3000│  │   │  ┌──────────────────┐ │   │  (CNPG PostgreSQL) │
   │  │ Next.js 16      │  │   │  │ JMAP API  :8080  │ │   │                    │
   │  │ + API Routes    │──│───│──│ SMTP      :25    │ │   │  Schema: webmail   │
   │  │ + JMAP Client   │  │   │  │ IMAP      :993   │ │   │  (settings only)   │
   │  │ + PWA + Push    │  │   │  │ CalDAV           │ │   │                    │
   │  └────────┬────────┘  │   │  │ CardDAV          │ │   └────────────────────┘
   │           │            │   │  │ ManageSieve      │ │
   │  ┌────────▼────────┐  │   │  │ Admin API        │ │
   │  │ webmail-api:3001│  │   │  └──────────────────┘ │
   │  │ Nitro H3        │  │   │  RocksDB PVC (20Gi)   │
   │  │ + SendCloud     │  │   │                       │
   │  │ + AI Features   │  │   └───────────────────────┘
   │  │ + Rules Engine  │  │
   │  │ + WebPush       │  │
   │  └────────┬────────┘  │
   │           │            │
   │  ┌────────▼────────┐  │
   │  │ Redis:6379      │  │
   │  │ (cache+queues)  │  │
   │  └─────────────────┘  │
   └────────────────────────┘

   Removed: Kong, GoTrue, PostgREST, Typesense, Supabase Auth
```

### v1.0 → v2.0 Component Diff

| Component | v1.0 | v2.0 | Change |
|-----------|------|------|--------|
| webmail-web | Next.js + Supabase JS Client | Next.js + JMAP Client (jmap-jam) | **Protocol change** |
| webmail-worker | Nitro + ImapFlow + Drizzle | Nitro + JMAP + minimal Drizzle | **Simplified** |
| Kong | API gateway for Supabase | — | **Removed** |
| GoTrue | Supabase Auth server | — | **Removed** |
| PostgREST | RESTful DB access | — | **Removed** |
| Supabase Realtime | Real-time subscriptions | JMAP push + Web Push | **Replaced** |
| Typesense | Full-text search | Stalwart built-in search | **Replaced** |
| Redis | BullMQ queues + sessions | BullMQ queues + cache | **Kept** |
| Stalwart | MTA (IMAP/SMTP) | **Primary data store** (JMAP/IMAP/SMTP/DAV) | **Elevated** |
| PostgreSQL | Full mail storage | App metadata only | **Reduced scope** |

**Net result: 8+ pods → 4 pods (web, api, redis, stalwart)**

---

## 2. Component Architecture / 组件架构

### 2.1 Frontend: webmail-web (Next.js)

| Aspect | Decision |
|--------|----------|
| Framework | Next.js 16 + React 19 |
| UI Library | Mantine 8 + TipTap 3 (Rich Text) |
| JMAP Client | jmap-jam (TypeScript, zero-dep) |
| Auth | Zitadel OIDC PKCE → httpOnly JWT cookie |
| State | React Context + Server Components + JMAP cache |
| PWA | Service Worker + Web Push (VAPID) |
| Styling | Tailwind CSS 4 |
| Deploy | Docker, port 3000 |

**Key Routes:**
- `/auth/login` — Zitadel OIDC redirect (PKCE flow)
- `/auth/callback` — OIDC callback, JWT cookie set
- `/dashboard/(mail)/` — Mailbox UI (JMAP-powered)
- `/dashboard/(calendar)/` — Calendar UI (Stalwart CalDAV proxy)
- `/dashboard/(contacts)/` — Contacts UI (Stalwart CardDAV proxy)
- `/api/jmap/*` — JMAP proxy to Stalwart (server-side)
- `/api/send` — Smart mail routing endpoint
- `/api/ai/*` — AI feature endpoints

**JMAP Integration Pattern:**
```
Browser (jmap-jam client)
  → Next.js API Route (/api/jmap)   [auth middleware adds Stalwart token]
    → Stalwart JMAP API (:8080)     [direct HTTP JSON]
      → Response flows back
```

### 2.2 Backend: webmail-api (Nitro, renamed from worker)

| Aspect | Decision |
|--------|----------|
| Runtime | Nitro (Node.js / Bun) |
| Role | Thin service layer (NOT data sync) |
| Queue | BullMQ (Redis-backed) |
| Events | NATS (WEBMAIL_EVENTS stream) |
| AI | HTTP calls to lurus-api (LLM gateway) |
| DB | Drizzle ORM (PostgreSQL, app metadata only) |
| Deploy | Docker, port 3001 |

**Responsibilities (dramatically reduced):**

| Responsibility | v1.0 | v2.0 |
|----------------|------|------|
| IMAP sync | Yes (core) | **Removed** (JMAP direct) |
| IMAP IDLE | Yes (core) | **Removed** (JMAP push) |
| PostgreSQL mail storage | Yes (core) | **Removed** (Stalwart stores) |
| Typesense indexing | Yes | **Removed** (Stalwart search) |
| DAV sync | Yes (custom) | **Removed** (Stalwart native) |
| SendCloud routing | Yes | **Kept** |
| Email rules | Yes | **Migrated to Sieve** |
| Webhooks | Yes | **Kept** |
| Background jobs | Yes | **Kept (reduced)** |
| AI features | No | **New** |
| Web Push | No | **New** |
| NATS events | No | **New** |

### 2.3 Mail Server: Stalwart (Elevated to Primary Data Store)

| Aspect | Decision |
|--------|----------|
| Server | Stalwart Mail Server (Rust) |
| Protocols | **JMAP** (primary), IMAP (external clients), SMTP, ManageSieve |
| DAV | CalDAV + CardDAV + WebDAV (native) |
| Search | Built-in full-text (FTS, or ElasticSearch backend) |
| Storage | RocksDB on 20Gi PVC |
| Auth | Stalwart OIDC → Zitadel (direct integration) |
| Admin | REST API + Web Admin UI |
| Namespace | `mail` (isolated) |

**Stalwart OIDC Configuration:**
```toml
[oauth]
oidc.issuer = "https://auth.lurus.cn"
oidc.client-id = "<webmail-client-id>"
oidc.client-secret = "<webmail-client-secret>"
```

This allows Stalwart to authenticate users directly against Zitadel, enabling JMAP access with the same SSO credentials.

### 2.4 Database: PostgreSQL (Reduced Scope)

| Aspect | Decision |
|--------|----------|
| Provider | CNPG (shared instance) |
| Host | lurus-pg-rw.database.svc:5432 |
| Database | webmail |
| Role | **App metadata only** (NOT mail storage) |
| Auth | JWT claims via `set_config` → RLS |

**Remaining Tables (v2.0):**

| Table | Purpose |
|-------|---------|
| user_settings | User preferences (theme, language, signature, etc.) |
| email_rules | Rule definitions (migrated to Sieve on apply) |
| api_keys | Service-to-service auth tokens |
| webhooks | User webhook registrations |
| ai_metadata | AI-generated summaries, categories per message_id |
| push_subscriptions | Web Push subscription endpoints |
| audit_log | Key operations log |

**Deprecated Tables (to be archived):**
- messages, threads, mailboxes, attachments, contacts, calendars, calendar_events, address_books, labels, identities

### 2.5 Cache: Redis

| Aspect | Decision |
|--------|----------|
| Purpose | BullMQ job queue + JMAP session cache + rate limiting |
| Key Prefix | `webmail:` (migrated from `kurrier:`) |
| Deployment | Single pod, lurus-webmail namespace |

### 2.6 Event Bus: NATS (New)

| Aspect | Decision |
|--------|----------|
| Stream | WEBMAIL_EVENTS |
| Subjects | `webmail.mail.received`, `webmail.mail.sent`, `webmail.mail.bounced` |
| Purpose | 跨服务事件通知（其他 Lurus 服务可订阅邮件事件） |
| Integration | Stalwart webhook → API → NATS publish |

---

## 3. Data Flow / 数据流

### 3.1 Incoming Mail (v2.0)

```
External sender → DNS MX → Traefik TCP :25
  → Stalwart SMTP
    → Stalwart stores in RocksDB (JMAP Mailbox)
    → Stalwart webhook fires → webmail-api
      → AI categorization (async, via lurus-api)
      → NATS publish: webmail.mail.received
      → Web Push notification to subscribed browsers
    → JMAP push event → Connected web clients auto-refresh
```

**Key difference from v1.0:** No IMAP sync, no PostgreSQL write, no Typesense index. Stalwart is the single source of truth.

### 3.2 Outgoing Mail (v2.0)

```
User composes in TipTap editor
  → POST /api/send (Next.js API route)
    → Auth middleware verifies JWT
    → webmail-api receives request
      → Route decision:
        ├─ China domain → SendCloud SMTP relay (smtp.sendcloud.net:587)
        └─ International → Stalwart JMAP EmailSubmission
      → OTel span: email.send (trace routing decision)
      → Store in JMAP Sent mailbox (automatic for Stalwart submission)
      → NATS publish: webmail.mail.sent
```

### 3.3 Auth Flow (v2.0 — Simplified)

```
User visits mail.lurus.cn
  → Next.js middleware checks httpOnly JWT cookie
    → No cookie → Redirect to Zitadel OIDC (PKCE)
      → Zitadel authenticates → Callback with auth code
        → Next.js server exchanges code for tokens
          → Set httpOnly JWT cookie (access + refresh)
          → Ensure Stalwart account exists (Admin API upsert)
            → Redirect to /dashboard
  → Cookie valid → Server-side JWT verification
    → JMAP requests use Stalwart OIDC token (derived from Zitadel)
    → PostgreSQL queries use set_config for RLS
```

**Auth token flow:**
```
Zitadel JWT → Next.js API route middleware verifies
           → For JMAP: Exchange/use Stalwart OIDC access token
           → For PostgreSQL: set_config('request.jwt.claims', claims, true)
```

### 3.4 AI Feature Flow

```
AI Summarization:
  New mail arrives (or user requests summary)
    → webmail-api fetches mail content via JMAP
    → POST to lurus-api /v1/chat/completions
      (model: claude-haiku-4-5, prompt: summarize/categorize)
    → Store AI metadata in PostgreSQL (ai_metadata table)
    → Return to frontend (cached in Redis, 1h TTL)

AI Smart Reply:
  User views email → clicks "Smart Reply"
    → Frontend sends email content to /api/ai/reply
    → webmail-api → lurus-api (generate 3 reply options)
    → Return options to frontend
    → User selects/edits → normal send flow
```

### 3.5 Calendar/Contacts Flow (v2.0)

```
Web UI:
  Browser → Next.js /api/dav/* → Stalwart CalDAV/CardDAV endpoint
  (Thin proxy with auth header injection)

Mobile:
  iOS/Android → Stalwart CalDAV/CardDAV (direct, authenticated via Zitadel OIDC)
  No webmail-api involvement needed
```

### 3.6 Search Flow (v2.0)

```
User types search query
  → Frontend → /api/jmap (JMAP Email/query with filter)
  → Stalwart processes search (built-in FTS or ElasticSearch)
  → Results returned as JMAP Email objects
  → Frontend renders (virtual scroll for large result sets)
```

### 3.7 Web Push Flow (New)

```
Setup:
  PWA install → Service Worker registers
    → pushManager.subscribe({ applicationServerKey: VAPID_PUBLIC })
    → Send subscription to /api/push/subscribe
    → Store in PostgreSQL push_subscriptions table

Notification:
  New mail → Stalwart webhook → webmail-api
    → Lookup push_subscriptions for user
    → For each subscription:
      → web-push library → Browser push service → Service Worker
        → self.registration.showNotification("New email from Alice")
```

---

## 4. Architecture Decision Records / 架构决策记录

### ADR-01: Remove Supabase Auth Stack (NEW)

**Context:** 当前运行 Kong、GoTrue、PostgREST 仅为桥接 Zitadel OIDC。这增加了 4 个 Pod、复杂的认证链路、和额外的维护负担。

**Decision:** 完全移除 Supabase Auth 栈。使用 Zitadel OIDC PKCE 直接在 Next.js 中处理认证，JWT 通过 httpOnly cookie 存储。PostgreSQL RLS 通过 `set_config` 驱动。

**Consequences:**
- (+) 减少 4 个 Pod
- (+) 认证链路从 6 步减至 2 步
- (+) 消除 Supabase JS Client 依赖
- (-) 需要重写所有 `@lurus/webmail-api-client` 中的 Supabase 调用
- (-) 需要在 Next.js 中实现 JWT refresh 逻辑

### ADR-02: JMAP as Primary Mail Protocol (NEW)

**Context:** Stalwart 以 JMAP 为核心构建，是目前最完整的 JMAP 实现。当前通过 IMAP 同步到 PostgreSQL 属于冗余。

**Decision:** 使用 JMAP (via jmap-jam library) 作为前端与 Stalwart 的主要通信协议。保留 IMAP 仅用于外部客户端（Thunderbird、移动 IMAP 客户端）。

**Consequences:**
- (+) 请求效率提升 20 倍
- (+) 内建推送通知（JMAP push）
- (+) 增量同步原生支持
- (+) 消除 PostgreSQL 中的邮件数据表
- (-) jmap-jam 库相对较新，可能需要 contribute patches
- (-) 需要 JMAP proxy 层处理认证

### ADR-03: Stalwart as Single Source of Truth (NEW)

**Context:** 当前邮件数据存在两份：Stalwart RocksDB 和 PostgreSQL。这导致同步问题和数据不一致。

**Decision:** Stalwart 是邮件/日历/联系人/存储的唯一数据源。PostgreSQL 仅存储应用级元数据（settings, rules, API keys, AI metadata）。

**Consequences:**
- (+) 消除数据同步问题
- (+) 大幅减少 PostgreSQL 存储需求
- (+) Stalwart 的 Rust 实现更高效
- (-) 对 Stalwart 的依赖增加（单点风险）
- (-) 需要可靠的 Stalwart 备份策略

**Mitigation:** RocksDB 定期备份到 MinIO，文档化恢复流程，保持 IMAP 外部访问作为应急。

### ADR-04: Replace Typesense with Stalwart Built-in Search (NEW)

**Context:** Typesense 需要独立 Pod、数据索引同步、额外的 API 密钥管理。Stalwart 内建全文搜索已足够满足 2 人团队需求。

**Decision:** 移除 Typesense。邮件搜索通过 JMAP Email/query 的 filter 参数实现，使用 Stalwart 内建 FTS。

**Consequences:**
- (+) 减少 1 个 Pod
- (+) 消除搜索索引同步问题
- (+) 搜索结果与邮件数据始终一致
- (-) Stalwart FTS 功能可能不如 Typesense 丰富
- (-) 大量邮件时搜索性能待验证

**Fallback:** 如果 Stalwart 内建搜索不够，可配置 Stalwart 的 ElasticSearch 后端。

### ADR-05: Namespace Isolation (KEPT from v1.0)

**Decision:** Stalwart 在独立 `mail` namespace，webmail 应用在 `lurus-webmail` namespace。

### ADR-06: Shared PostgreSQL (KEPT from v1.0)

**Decision:** 复用公司 CNPG PostgreSQL 实例。v2.0 中 PostgreSQL 存储量大幅减少。

### ADR-07: China Mail Relay via SendCloud (KEPT from v1.0)

**Decision:** 国内域名通过 SendCloud SMTP relay。

### ADR-08: Kustomize over Helm (KEPT from v1.0)

**Decision:** 使用 Kustomize。

### ADR-09: AI via lurus-api LLM Gateway (NEW)

**Context:** Lurus 已有 LLM 统一网关（lurus-api），支持 OpenAI/Anthropic/Google 等多供应商。

**Decision:** AI 功能通过调用 lurus-api 的 OpenAI 兼容 API 实现，不引入独立 AI 模型。

**Consequences:**
- (+) 复用已有基础设施
- (+) 模型可切换（Haiku for speed, Sonnet for quality）
- (+) 统一计费和用量追踪
- (-) 依赖 lurus-api 可用性（降级：禁用 AI 功能）

### ADR-10: NATS for Cross-Service Events (NEW)

**Context:** 其他 Lurus 服务需要知道邮件事件（如 lurus-identity 需要在用户注册时发送欢迎邮件）。

**Decision:** 使用公司统一 NATS 基础设施，创建 WEBMAIL_EVENTS stream。

**Consequences:**
- (+) 与公司事件总线统一
- (+) 支持持久化和重放
- (-) 增加 NATS 依赖（已有基础设施，非新增）

---

## 5. Security Architecture / 安全架构

| Layer | v1.0 | v2.0 |
|-------|------|------|
| Network | Traefik TLS | Traefik TLS + HSTS + CSP headers |
| Auth | Supabase JWT (via Kong) | **Zitadel JWT direct** (httpOnly cookie) |
| Database | Supabase RLS | **set_config RLS** (same security, simpler path) |
| Secrets | K8s Secrets (base64) | K8s Secrets (consider Sealed Secrets) |
| Mail Auth | DKIM + SPF + DMARC quarantine | **DKIM + SPF + DMARC reject + ARC** |
| Stalwart | Basic auth | **OIDC + fail2ban** |
| API | Supabase anon/service key | **Zitadel JWT + API key** |

### Email Authentication Target Configuration

```dns
; SPF (already configured)
lurus.cn.     TXT   "v=spf1 ip4:43.226.46.164 include:sendcloud.net -all"

; DKIM (Stalwart managed, 2048-bit, rotate annually)
dkim._domainkey.lurus.cn.   TXT   "v=DKIM1; k=rsa; p=<key>"

; DMARC (upgrade path: none → quarantine → reject)
_dmarc.lurus.cn.   TXT   "v=DMARC1; p=reject; rua=mailto:postmaster@lurus.cn; ruf=mailto:postmaster@lurus.cn; fo=1"

; ARC (for forwarded mail, configured in Stalwart)
; Stalwart signs ARC headers automatically when forwarding
```

---

## 6. Observability Architecture / 可观测性架构

### OpenTelemetry Spans (Mail Lifecycle)

```
Trace: email.send
├── Span: email.compose           (user action → API call)
├── Span: email.route.decide      (China vs International)
│   └── Attribute: route.channel = "sendcloud" | "stalwart"
├── Span: email.queue.enqueue     (BullMQ job created)
├── Span: email.queue.process     (worker picks up job)
├── Span: smtp.connect            (connect to SMTP server)
│   └── Attribute: smtp.host, smtp.port
├── Span: smtp.send               (SMTP transaction)
│   ├── Event: smtp.response      (250 OK / 550 reject)
│   └── Attribute: smtp.status_code, smtp.enhanced_code
└── Span: email.delivery.confirm  (delivery callback)
    └── Attribute: delivery.status = "delivered" | "bounced" | "deferred"

Trace: email.receive
├── Span: stalwart.webhook        (Stalwart fires webhook)
├── Span: ai.categorize           (LLM categorization)
├── Span: push.notify             (Web Push to browser)
└── Span: nats.publish            (WEBMAIL_EVENTS)
```

### Metrics (Prometheus)

| Metric | Type | Labels |
|--------|------|--------|
| `webmail_emails_sent_total` | Counter | channel, status |
| `webmail_emails_received_total` | Counter | domain |
| `webmail_send_duration_seconds` | Histogram | channel |
| `webmail_ai_requests_total` | Counter | feature, model |
| `webmail_jmap_requests_total` | Counter | method, status |
| `webmail_push_notifications_total` | Counter | status |
| `webmail_queue_depth` | Gauge | queue_name |

### Grafana Dashboard Panels

1. **Mail Overview**: 收发邮件数量趋势、成功/失败比
2. **Delivery Performance**: SendCloud vs Stalwart 投递延迟对比
3. **System Health**: Pod 状态、Redis 连接、JMAP 响应时间
4. **AI Usage**: AI 功能调用量、响应延迟、Token 消耗
5. **Stalwart Status**: 队列深度、存储使用、连接数

---

## 7. Deployment Architecture / 部署架构

### Pod Layout (v2.0)

| Pod | Namespace | Node | Resources |
|-----|-----------|------|-----------|
| webmail-web | lurus-webmail | K3s scheduler | 256Mi-512Mi, 0.2-0.5 CPU |
| webmail-api | lurus-webmail | K3s scheduler | 256Mi-512Mi, 0.2-0.5 CPU |
| redis | lurus-webmail | K3s scheduler | 128Mi-256Mi, 0.1-0.2 CPU |
| stalwart | mail | master (公网 IP) | 512Mi-1Gi, 0.5-1.0 CPU |

**Removed Pods:** kong, gotrue, postgrest, supabase-realtime, typesense

### Docker Images

```
ghcr.io/hanmahong5-arch/lurus-webmail-web:main     (Next.js standalone)
ghcr.io/hanmahong5-arch/lurus-webmail-api:main      (Nitro, renamed from worker)
```

### CI/CD Pipeline

```
Developer pushes to GitHub
  → GitHub Actions triggered
    → Bun install + lint + test
    → Build Docker images (multi-stage)
      → Push to GHCR
        → ArgoCD detects new image (office-debian-2, via v2ray)
          → Auto-sync to K3s cluster
```

### Kustomize Structure (v2.0)

```
k8s/
├── kustomization.yaml       # Updated: removed supabase, typesense
├── namespace.yaml           # lurus-webmail
├── secrets.yaml             # Simplified: no Supabase keys
├── configmap.yaml           # Stalwart JMAP URL, VAPID keys, AI config
├── webmail-app.yaml         # web + api deployments
├── redis.yaml               # Redis pod
├── ingress.yaml             # Traefik routes (simplified)
└── stalwart/                # Unchanged
    ├── statefulset.yaml
    ├── service.yaml
    └── configmap.yaml       # Updated: OIDC config added
```

---

## 8. Migration Architecture / 迁移架构

### Feature Flag Strategy

```typescript
// Environment variable driven
const FEATURE_FLAGS = {
  JMAP_ENABLED: process.env.JMAP_ENABLED === 'true',         // Phase 2
  SUPABASE_DISABLED: process.env.SUPABASE_DISABLED === 'true', // Phase 1
  AI_ENABLED: process.env.AI_ENABLED === 'true',              // Phase 3
  PWA_ENABLED: process.env.PWA_ENABLED === 'true',            // Phase 3
};
```

### Migration Phases

```
Phase 0: Foundation    [No architecture change]
  - Fix tech debt, configure credentials
  - Both paths work: Supabase + IMAP (current)

Phase 1: Auth Switch   [Remove Supabase Auth]
  - New: Zitadel OIDC direct in Next.js
  - Remove: Kong, GoTrue, PostgREST
  - Keep: IMAP sync (mail data still in PostgreSQL)

Phase 2: JMAP Switch   [Replace IMAP with JMAP]
  - New: jmap-jam client, JMAP proxy routes
  - Dual-read: JMAP primary, PostgreSQL fallback (feature flag)
  - Validate: Data consistency between JMAP and PostgreSQL

Phase 3: AI + Push     [Add new features]
  - New: AI summarization/categorization, PWA, Web Push
  - These are additive, no migration risk

Phase 4: Cleanup       [Remove deprecated components]
  - Remove: IMAP sync code, Typesense, deprecated PG tables
  - Remove: Supabase JS client, ImapFlow dependency
  - Final: Only 4 pods remain
```

---

## 9. Known Risks & Mitigations / 已知风险与缓解

| Risk | Severity | Mitigation |
|------|----------|------------|
| Stalwart JMAP API 不稳定 | High | Pin Stalwart version; E2E test JMAP flows; maintain IMAP fallback during migration |
| jmap-jam 库有 bug | Medium | Fork if needed; contribute upstream; library is small (~2KB) and auditable |
| Stalwart 备份丢失 | Critical | RocksDB snapshot to MinIO daily; document + test recovery procedure |
| JMAP push 延迟 | Low | Web Push as secondary channel; polling fallback (30s interval) |
| SendCloud 账户被封 | Medium | Monitor reputation; maintain clean mailing practices; no bulk sending |
| AI API 不可用 | Low | Graceful degradation: disable AI features, core mail unaffected |
