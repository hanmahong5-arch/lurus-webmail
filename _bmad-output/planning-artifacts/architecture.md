---
stepsCompleted: [init, context, decisions, patterns, structure, validate, finalize]
inputDocuments: [prd.md, product-brief.md, lurus.yaml, k8s/]
workflowType: 'architecture'
project_name: 'lurus-webmail'
user_name: 'Anita'
date: '2026-02-02'
---

# Architecture Decision Document

## 1. System Overview / 系统概览

```
                          ┌─────────────────────────────────────┐
                          │           Internet / DNS             │
                          │      MX: mail.lurus.cn → 43.226.46.164
                          └──────────────┬──────────────────────┘
                                         │
                          ┌──────────────▼──────────────────────┐
                          │  Traefik Ingress (K3s master)       │
                          │  ├─ HTTPS mail.lurus.cn → web:3000  │
                          │  ├─ TCP :25  → stalwart:25          │
                          │  ├─ TCP :465 → stalwart:465         │
                          │  ├─ TCP :587 → stalwart:587         │
                          │  └─ TCP :993 → stalwart:993         │
                          └──────────────┬──────────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              │                          │                          │
    ┌─────────▼──────────┐   ┌──────────▼──────────┐   ┌─────────▼──────────┐
    │  namespace:         │   │  namespace:          │   │  namespace:         │
    │  lurus-webmail      │   │  mail                │   │  database           │
    │                     │   │                      │   │                     │
    │  webmail-web:3000   │   │  stalwart:25/587/993 │   │  lurus-pg-rw:5432   │
    │  webmail-worker:3001│   │  stalwart-api:8080   │   │  (CNPG PostgreSQL)  │
    │  redis:6379         │   │  rocksdb PVC (20Gi)  │   │                     │
    │  typesense:8108     │   │                      │   │                     │
    │  supabase stack     │   │                      │   │                     │
    └─────────────────────┘   └──────────────────────┘   └─────────────────────┘
```

## 2. Component Architecture / 组件架构

### 2.1 Frontend: webmail-web (Next.js)

| Aspect | Decision |
|--------|----------|
| Framework | Next.js 15 + React |
| UI Library | Mantine + TipTap (Rich Text) |
| State | React Context + Server Components |
| Auth | Zitadel OIDC → Supabase Auth Session |
| API Client | Supabase JS Client (PostgREST) |
| Deploy | Docker (scratch/alpine), port 3000 |

**Key Routes:**
- `/auth/login` - Zitadel SSO redirect
- `/auth/signup` - Registration
- `/auth/callback` - OIDC callback
- `/dashboard/(unified)/(mail)/` - Mailbox UI
- `/api/kong/*` - API proxy to Supabase

### 2.2 Backend: webmail-worker (Nitro)

| Aspect | Decision |
|--------|----------|
| Runtime | Nitro (Node.js) |
| IMAP Sync | Custom IMAP client with IDLE support |
| SMTP Send | Direct Stalwart or SendCloud relay |
| Queue | Redis-backed job queue |
| API | REST endpoints on port 3001 |

**Key Responsibilities:**
- IMAP IDLE real-time sync (new mail detection)
- SMTP mail sending (route: China → SendCloud, International → Stalwart)
- Database migrations
- Background jobs (sync, cleanup)

### 2.3 Mail Server: Stalwart

| Aspect | Decision |
|--------|----------|
| Server | Stalwart Mail Server (Rust) |
| Protocols | SMTP (25/587), IMAP (993), HTTP API (8080) |
| Storage | RocksDB on 20Gi PVC |
| Namespace | `mail` (isolated from webmail) |
| TLS | Let's Encrypt via Traefik |

### 2.4 Database: PostgreSQL (CNPG)

| Aspect | Decision |
|--------|----------|
| Provider | CloudNativePG (shared instance) |
| Host | lurus-pg-rw.database.svc.cluster.local:5432 |
| Database | `webmail` (schema isolation) |
| Auth Model | Supabase-compatible (RLS + JWT) |
| Roles | supabase_auth_admin, rls_client |

### 2.5 Search: Typesense

| Aspect | Decision |
|--------|----------|
| Engine | Typesense v29.0 |
| Purpose | Full-text email search, contact search |
| Deployment | Single pod in lurus-webmail namespace |

### 2.6 Cache: Redis

| Aspect | Decision |
|--------|----------|
| Version | Redis 8.2.2 |
| Purpose | Session cache, job queue, IMAP state |
| Key Prefix | `kurrier:` (upstream convention) |
| Deployment | Single pod in lurus-webmail namespace |

## 3. Data Flow / 数据流

### 3.1 Incoming Mail Flow

```
External sender → DNS MX → Traefik TCP :25
  → Stalwart SMTP (mail namespace)
    → Stalwart stores in RocksDB
      → Worker IMAP IDLE detects new mail
        → Worker syncs to PostgreSQL
          → Typesense indexes content
            → Web UI shows new mail (real-time)
```

### 3.2 Outgoing Mail Flow

```
User composes mail in Web UI
  → Worker receives send request
    → Route decision:
      ├─ China domain (qq/163/126/etc.) → SendCloud SMTP relay
      └─ International domain → Stalwart direct SMTP
    → Store in Sent folder (PostgreSQL)
```

### 3.3 Auth Flow

```
User visits mail.lurus.cn
  → Next.js SSR checks session
    → No session → Redirect to Zitadel OIDC
      → Zitadel auth → Callback with code
        → Exchange code for tokens
          → Supabase Auth creates/updates session
            → JWT issued → PostgreSQL RLS enforced
```

## 4. Infrastructure Decisions / 基础设施决策

### ADR-01: Namespace Isolation

**Decision:** Stalwart 在独立 `mail` namespace，webmail 应用在 `lurus-webmail` namespace。

**Rationale:** Stalwart 是底层 MTA，可能被其他服务复用。隔离 namespace 避免应用层故障影响邮件收发。

### ADR-02: Shared PostgreSQL

**Decision:** 复用公司 CNPG PostgreSQL 实例，使用 `webmail` database。

**Rationale:** 2 人团队不需要独立数据库集群。CNPG 提供自动备份、failover。Schema 隔离足够。

### ADR-03: China Mail Relay

**Decision:** 国内域名（qq.com, 163.com 等）通过 SendCloud SMTP relay 投递。

**Rationale:** 国内邮件服务商对未知 IP 的拒收率极高。SendCloud 有 IP 信誉白名单，投递率 > 95%。

### ADR-04: Supabase-Compatible Auth

**Decision:** 保留 kurrier 上游的 Supabase Auth 架构（PostgREST + JWT + RLS）。

**Rationale:** 上游深度依赖 Supabase Auth 模型。替换成本远大于保留。通过 Zitadel OIDC 桥接统一登录。

### ADR-05: Kustomize over Helm

**Decision:** 使用 Kustomize 管理 K8s 配置，不用 Helm。

**Rationale:** 配置简单直观，不需要 chart 抽象层。ArgoCD 原生支持 Kustomize。

## 5. Deployment Architecture / 部署架构

### Node Placement

| Component | Node | Reason |
|-----------|------|--------|
| webmail-web | K3s scheduler | 无特殊要求 |
| webmail-worker | K3s scheduler | 无特殊要求 |
| Stalwart | master (43.226.46.164) | 需要公网 IP 接收邮件 |
| PostgreSQL | database node | CNPG 管理 |
| ArgoCD | office-debian-2 | v2ray 代理访问 GitHub |

### CI/CD Pipeline

```
Developer pushes to GitHub
  → GitHub Actions triggered
    → Build Docker images (amd64 + arm64)
      → Push to GHCR (ghcr.io/hanmahong5-arch/)
        → ArgoCD detects new image (office-debian-2, via v2ray)
          → Auto-sync to K3s cluster
```

### Image Naming Convention

```
ghcr.io/hanmahong5-arch/lurus-webmail-web:<version>
ghcr.io/hanmahong5-arch/lurus-webmail-worker:<version>
```

## 6. Security Architecture / 安全架构

| Layer | Mechanism |
|-------|-----------|
| Network | Traefik TLS termination, HTTPS only |
| Auth | Zitadel OIDC + Supabase JWT |
| Database | PostgreSQL RLS per-user isolation |
| Secrets | K8s Secrets (base64, consider Sealed Secrets) |
| Mail | DKIM + SPF + DMARC on lurus.cn |
| Internal | ClusterIP services, no external exposure |

## 7. Monitoring & Observability / 监控

| Tool | Purpose | Endpoint |
|------|---------|----------|
| Prometheus | Metrics collection | grafana.lurus.cn |
| Grafana | Dashboard | grafana.lurus.cn |
| Loki | Log aggregation | loki.lurus.cn |
| Jaeger | Tracing | jaeger.lurus.cn |
| ArgoCD | Deployment status | argocd.lurus.cn |

## 8. Known Technical Debt / 已知技术债务

| Item | Severity | Description |
|------|----------|-------------|
| Redis key prefix | Low | 仍使用 `kurrier:` 前缀，应迁移为 `lurus-webmail:` |
| Default sender | Low | 邮件提供商默认发件人仍为 `no-reply@kurrier.org` |
| Zitadel TODO | High | SSO Client ID/Secret 未配置 |
| SendCloud TODO | High | API 凭据未配置 |
| Stalwart TODO | Medium | Admin 密码未配置 |
| Supabase JWT issuer | Low | JWT iss 为 `lurus-kurrier`，应为 `lurus-webmail` |
| init-db.sql | Low | 数据库名仍为 `kurrier` |
| Cross-node DNS | Medium | K3s 跨节点 DNS 解析有问题（已用 ClusterIP 绕过） |
