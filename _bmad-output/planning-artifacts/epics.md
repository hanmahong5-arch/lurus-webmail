---
stepsCompleted: [validate-prereqs, design-epics, create-stories, final-validate]
inputDocuments: [prd.md v2.0, architecture.md v2.0, product-brief.md v2.0]
version: 2.0
date: 2026-02-27
supersedes: epics.md v1.0 (2026-02-02)
---

# lurus-webmail v2.0 — Epic & Story Breakdown

## Overview

改造计划分为 6 个 Epic，按依赖关系排序。每个 Phase 可独立交付价值，保证迁移期间服务不中断。

## Requirements Coverage Map

| Requirement | Epic |
|-------------|------|
| FR-03 (Auth) | Epic 1 |
| FR-01 (JMAP Mail) | Epic 2 |
| FR-02 (Smart Routing) | Epic 1 (Story 1.5) + Epic 2 |
| FR-04 (Calendar/Contacts) | Epic 4 |
| FR-05 (AI Features) | Epic 3 |
| FR-06 (PWA/Push) | Epic 3 |
| FR-07 (Rules) | Epic 4 |
| FR-08 (Mail API) | Epic 4 |
| NFR-01 (Security) | Epic 1 |
| NFR-02 (Observability) | Epic 5 |
| NFR-03 (Deployment) | Epic 5 |
| NFR-04 (Performance) | Epic 2 |
| NFR-05 (Maintainability) | Epic 0 + Epic 5 |

## Epic Summary

| # | Epic | Priority | Est. Duration | Dependencies |
|---|------|----------|---------------|-------------|
| 0 | Foundation & Tech Debt | P0 | 2 weeks | None |
| 1 | Auth Overhaul | P0 | 2 weeks | Epic 0 |
| 2 | JMAP Core Migration | P0 | 3 weeks | Epic 1 |
| 3 | AI Features & PWA | P1 | 2 weeks | Epic 2 |
| 4 | DAV Native & Automation | P1 | 2 weeks | Epic 2 |
| 5 | Cleanup & Observability | P1 | 1 week | Epic 2, 3, 4 |

---

## Epic 0: Foundation & Tech Debt

**Goal:** 清除所有遗留命名、配置缺失和安全隐患，为后续改造建立干净基础。

**Duration:** 2 weeks

### Story 0.1: Rename All Kurrier References

As a developer,
I want all `kurrier` references replaced with `lurus-webmail`,
So that the codebase reflects the actual project identity.

**Acceptance Criteria:**
- [ ] Redis key prefix `kurrier:` → `webmail:` (with migration script for existing keys)
- [ ] JWT issuer `lurus-kurrier` → `lurus-webmail`
- [ ] Default sender `no-reply@kurrier.org` → `no-reply@lurus.cn`
- [ ] init-db.sql database name `kurrier` → `webmail`
- [ ] API path `/api/kurrier/*` → `/api/mail/*`
- [ ] `grep -r kurrier` returns zero matches (excluding git history)
- [ ] All existing functionality continues to work after rename

### Story 0.2: Configure SendCloud Credentials

As a system admin,
I want SendCloud API credentials configured and verified,
So that China domain mail routing is operational.

**Acceptance Criteria:**
- [ ] SendCloud API Key and API User configured in K8s secrets
- [ ] Test email sent to qq.com address via SendCloud relay
- [ ] Delivery confirmed (check SendCloud dashboard)
- [ ] Routing logic verified: China domain → SendCloud, others → Stalwart

### Story 0.3: Configure Stalwart Admin & OIDC

As a system admin,
I want Stalwart properly secured and integrated with Zitadel,
So that it's ready for direct JMAP access.

**Acceptance Criteria:**
- [ ] Stalwart admin password set to secure random value (not default)
- [ ] Stalwart OIDC configured to authenticate against Zitadel
- [ ] Stalwart JMAP endpoint accessible from lurus-webmail namespace
- [ ] Stalwart Admin API accessible from webmail-api pod
- [ ] Test: JMAP request with Zitadel-issued token returns mailbox data

### Story 0.4: Harden Email Authentication (DMARC/ARC)

As a system admin,
I want DMARC upgraded to `p=reject` and ARC enabled,
So that lurus.cn email has maximum deliverability and security.

**Acceptance Criteria:**
- [ ] DMARC record updated: `p=quarantine` (intermediate step)
- [ ] Monitor DMARC reports for 1 week (rua=postmaster@lurus.cn)
- [ ] If no false positives: upgrade to `p=reject`
- [ ] ARC signing enabled in Stalwart for forwarded messages
- [ ] PTR record verified for 43.226.46.164 → mail.lurus.cn
- [ ] Verify: `dig TXT _dmarc.lurus.cn` shows `p=reject`
- [ ] Verify: Send test to Gmail, check "Show Original" → SPF/DKIM/DMARC all PASS

### Story 0.5: Create Zitadel OIDC Application for Webmail

As a system admin,
I want a Zitadel OIDC application created for mail.lurus.cn,
So that direct authentication is possible without Supabase.

**Acceptance Criteria:**
- [ ] Zitadel Application created (type: Web, PKCE flow)
- [ ] Redirect URI: `https://mail.lurus.cn/auth/callback`
- [ ] Post-logout URI: `https://mail.lurus.cn/auth/login`
- [ ] Scopes: openid, profile, email
- [ ] Client ID stored in K8s secret
- [ ] Client Secret stored in K8s secret (if confidential client)
- [ ] Test: OIDC discovery endpoint returns correct config

---

## Epic 1: Auth Overhaul

**Goal:** 移除 Supabase Auth 全栈，实现 Zitadel OIDC 直连。

**Duration:** 2 weeks
**Depends on:** Epic 0 (Zitadel OIDC app created, Stalwart OIDC configured)

### Story 1.1: Implement Zitadel OIDC in Next.js

As a team member,
I want to login via Zitadel directly without Supabase intermediary,
So that authentication is faster and simpler.

**Acceptance Criteria:**
- [ ] Next.js `/auth/login` initiates OIDC PKCE flow to Zitadel
- [ ] `/auth/callback` exchanges auth code for tokens
- [ ] Access + refresh tokens stored in httpOnly secure cookies
- [ ] Middleware validates JWT on every protected route
- [ ] Token refresh handled automatically (before expiry)
- [ ] `/auth/logout` clears cookies + Zitadel end_session
- [ ] E2E test: Login → Dashboard → Logout flow works

### Story 1.2: Implement JWT-Driven PostgreSQL RLS

As a developer,
I want PostgreSQL RLS driven by Zitadel JWT claims,
So that data isolation works without Supabase Auth.

**Acceptance Criteria:**
- [ ] Helper function `current_user_id()` reads from `request.jwt.claims`
- [ ] RLS policies on remaining tables use `current_user_id()`
- [ ] API middleware: `SET LOCAL` config on every DB transaction
- [ ] Test: User A cannot read User B's settings/rules/webhooks
- [ ] Test: Invalid JWT results in 401, not data leak

### Story 1.3: Implement Stalwart Account Auto-Provisioning

As a new user,
I want my Stalwart mailbox created automatically on first login,
So that I can immediately use email without admin intervention.

**Acceptance Criteria:**
- [ ] On first OIDC login, check if Stalwart account exists (Admin API)
- [ ] If not, create account with Zitadel sub as identifier
- [ ] Set email address: `{username}@lurus.cn`
- [ ] Account linked to Zitadel OIDC for subsequent auth
- [ ] Test: New user logs in → Stalwart account created → JMAP accessible

### Story 1.4: Replace Supabase JS Client Calls

As a developer,
I want all Supabase client calls replaced with direct API calls,
So that the Supabase dependency is fully removed.

**Acceptance Criteria:**
- [ ] `@lurus/webmail-api-client` rewritten: Supabase → fetch + JWT header
- [ ] All `supabase.from('table').select()` → Drizzle ORM queries via API routes
- [ ] All `supabase.auth.*` → Zitadel OIDC functions
- [ ] All `supabase.storage.*` → JMAP Blob (for attachments) or direct upload
- [ ] `@supabase/supabase-js` removed from package.json
- [ ] Build passes with no Supabase imports
- [ ] All existing UI features still work (mail list, compose, labels, etc.)

### Story 1.5: Remove Supabase K8s Resources

As a system admin,
I want Supabase pods removed from the cluster,
So that resources are freed and maintenance burden reduced.

**Acceptance Criteria:**
- [ ] Kong deployment removed from k8s/
- [ ] GoTrue deployment removed from k8s/
- [ ] PostgREST deployment removed from k8s/ (if present)
- [ ] Supabase-related secrets cleaned up
- [ ] Supabase-related ConfigMaps cleaned up
- [ ] `kubectl get pods -n lurus-webmail` shows no Supabase pods
- [ ] All email features verified working after removal
- [ ] Next.js API rewrites to `/api/kong/*` removed

---

## Epic 2: JMAP Core Migration

**Goal:** 将邮件数据访问从 IMAP sync + PostgreSQL 迁移到 JMAP 直连 Stalwart。

**Duration:** 3 weeks
**Depends on:** Epic 1 (auth works without Supabase, Stalwart OIDC ready)

### Story 2.1: Implement JMAP Client Layer

As a developer,
I want a JMAP client layer that talks to Stalwart,
So that mail data comes directly from the authoritative source.

**Acceptance Criteria:**
- [ ] `jmap-jam` library integrated (or equivalent TypeScript JMAP client)
- [ ] JMAP session discovery via Stalwart `/.well-known/jmap`
- [ ] Auth: Stalwart OIDC token (derived from Zitadel session)
- [ ] Core methods implemented:
  - `getMailboxes()` — list all mailboxes
  - `getEmails(mailboxId, options)` — paginated email list
  - `getEmail(emailId)` — full email with body
  - `getThread(threadId)` — thread with all emails
  - `searchEmails(query)` — full-text search
- [ ] Unit tests for JMAP client methods (mocked Stalwart responses)
- [ ] Integration test against live Stalwart JMAP endpoint

### Story 2.2: Implement JMAP API Proxy Routes

As a frontend developer,
I want Next.js API routes that proxy JMAP requests to Stalwart,
So that the frontend doesn't need direct Stalwart access.

**Acceptance Criteria:**
- [ ] `POST /api/jmap` — Generic JMAP request proxy (adds auth header)
- [ ] `GET /api/jmap/session` — JMAP session (cached in Redis, 5min TTL)
- [ ] Auth middleware: validate Zitadel JWT → inject Stalwart token
- [ ] Rate limiting: 100 requests/minute per user
- [ ] Error handling: Stalwart errors mapped to HTTP status codes
- [ ] CORS: Only mail.lurus.cn origin allowed

### Story 2.3: Migrate Inbox UI to JMAP

As a team member,
I want the inbox to load from JMAP instead of PostgreSQL,
So that I see the most up-to-date mail without sync delays.

**Acceptance Criteria:**
- [ ] Inbox page fetches mailbox list via JMAP
- [ ] Email list uses JMAP Email/query with pagination
- [ ] Thread view uses JMAP Thread/get
- [ ] Email detail uses JMAP Email/get with bodyValues
- [ ] Virtual scrolling works with JMAP-sourced data
- [ ] Feature flag: `JMAP_ENABLED=true` switches to JMAP; `false` uses old path
- [ ] Performance: Inbox load < 1s (measured)

### Story 2.4: Implement JMAP Push for Real-Time Updates

As a team member,
I want new emails to appear instantly without polling,
So that I never miss a time-sensitive message.

**Acceptance Criteria:**
- [ ] JMAP EventSource connection established on page load
- [ ] Stalwart push event triggers mailbox refresh
- [ ] New email count badge updates in real-time
- [ ] Connection auto-reconnects on disconnect (exponential backoff)
- [ ] Fallback: 30s polling if EventSource not supported
- [ ] Test: Send email to Stalwart → appears in UI within 1s

### Story 2.5: Migrate Email Send to JMAP Submission

As a team member,
I want to send email through JMAP (for international) and SendCloud (for China),
So that delivery is reliable to all recipients.

**Acceptance Criteria:**
- [ ] Compose UI unchanged (TipTap editor)
- [ ] Submit triggers route decision:
  - China domains → existing SendCloud SMTP path (via webmail-api)
  - International → JMAP EmailSubmission/set (direct to Stalwart)
- [ ] Sent email appears in Sent mailbox (automatic for JMAP submission)
- [ ] Attachments uploaded via JMAP Blob/upload
- [ ] OTel span covers full send flow
- [ ] Test: Send to Gmail → arrives; Send to qq.com → arrives via SendCloud

### Story 2.6: Migrate Search to JMAP Query

As a team member,
I want email search powered by Stalwart directly,
So that search results are always consistent with my mailbox.

**Acceptance Criteria:**
- [ ] Search bar triggers JMAP Email/query with text filter
- [ ] Results rendered as email list (same component as inbox)
- [ ] Advanced filters: from, to, subject, date range, has:attachment
- [ ] Search performance: < 500ms for typical queries
- [ ] Typesense search code deprecated (behind feature flag)

### Story 2.7: Migrate Labels/Folders to JMAP Mailbox + Keywords

As a team member,
I want labels and folders to work via JMAP,
So that organizing email is instant and consistent.

**Acceptance Criteria:**
- [ ] Custom labels mapped to JMAP keywords (e.g., `$label_important`)
- [ ] Folder operations (move, archive, trash) use JMAP Email/set
- [ ] Label CRUD: Create → JMAP Mailbox/set; Apply → Email/set keywords
- [ ] Multi-select + batch operations work via JMAP batch requests
- [ ] Color metadata stored in PostgreSQL user_settings (JMAP doesn't support colors)

---

## Epic 3: AI Features & PWA

**Goal:** 利用 LLM 基础设施实现智能邮件功能，并通过 PWA 提供推送通知。

**Duration:** 2 weeks
**Depends on:** Epic 2 (JMAP working, mail data accessible)

### Story 3.1: Implement Thread Summarization

As a team member,
I want long email threads automatically summarized,
So that I can quickly understand the conversation without reading every message.

**Acceptance Criteria:**
- [ ] Threads with ≥ 3 emails show "Summarize" button
- [ ] Click triggers: Fetch thread via JMAP → Send to lurus-api LLM → Display summary
- [ ] Summary cached in PostgreSQL ai_metadata table (key: thread_id, TTL: 24h)
- [ ] Summary invalidated when new email added to thread
- [ ] Model: Claude Haiku 4.5 (fast, cost-effective)
- [ ] Prompt: Concise summary in user's language, action items highlighted
- [ ] Graceful degradation: If LLM unavailable, hide button (no error)
- [ ] Test: Summarize 10-email thread → coherent 3-sentence summary

### Story 3.2: Implement Smart Categorization

As a team member,
I want incoming emails automatically categorized,
So that I can focus on important messages first.

**Acceptance Criteria:**
- [ ] Categories: Important, Notification, Marketing, Social, Other
- [ ] On new email arrival (Stalwart webhook → webmail-api):
  - Fetch email content via JMAP
  - Send to LLM for categorization
  - Store category in PostgreSQL ai_metadata
  - Set JMAP keyword (e.g., `$category_important`)
- [ ] Inbox UI shows category badges
- [ ] Filter by category (dropdown or tabs)
- [ ] Processing is async (BullMQ job), doesn't delay mail delivery
- [ ] Batch categorize: On first setup, categorize last 50 emails

### Story 3.3: Implement Smart Reply Suggestions

As a team member,
I want AI-generated reply suggestions,
So that I can respond to emails faster.

**Acceptance Criteria:**
- [ ] Email detail view shows "Smart Reply" section (3 options)
- [ ] Options generated by LLM based on email content + context
- [ ] Click option → inserts into compose editor (editable)
- [ ] Tone options: Professional, Casual, Brief
- [ ] Suggestions cached per email_id (Redis, 1h TTL)
- [ ] Test: Receive meeting invite → suggestions include "Accept", "Decline", "Suggest alternative"

### Story 3.4: Implement PWA Service Worker

As a team member,
I want mail.lurus.cn installable as a PWA,
So that I get an app-like experience and offline access to the UI shell.

**Acceptance Criteria:**
- [ ] `manifest.json` with app name, icons, theme color, start_url
- [ ] Service Worker registered (Next.js PWA pattern)
- [ ] App shell (navigation, sidebar) cached for offline
- [ ] "Add to Home Screen" prompt on mobile browsers
- [ ] iOS: Works after "Add to Home Screen"
- [ ] Lighthouse PWA audit: Installable ✓

### Story 3.5: Implement Web Push Notifications

As a team member,
I want push notifications for new emails even when the tab is closed,
So that I don't miss important messages.

**Acceptance Criteria:**
- [ ] VAPID key pair generated and stored in K8s secrets
- [ ] User opts in to notifications (permission prompt)
- [ ] Push subscription stored in PostgreSQL push_subscriptions table
- [ ] New email flow: Stalwart webhook → webmail-api → web-push to all user subscriptions
- [ ] Notification shows: sender name, subject line, truncated preview
- [ ] Click notification → opens mail.lurus.cn to that email
- [ ] Unsubscribe: Settings page toggle
- [ ] Test: Close all tabs → send email → notification appears

---

## Epic 4: DAV Native & Automation

**Goal:** 将日历/联系人切换到 Stalwart 原生 CalDAV/CardDAV，实现邮件规则和服务间 API。

**Duration:** 2 weeks
**Depends on:** Epic 2 (JMAP working)

### Story 4.1: Migrate Calendar to Stalwart CalDAV

As a team member,
I want calendar powered by Stalwart's native CalDAV,
So that calendar sync works across all devices without custom code.

**Acceptance Criteria:**
- [ ] Calendar Web UI fetches events from Stalwart CalDAV (via API proxy)
- [ ] Create/edit/delete events in Web UI → writes to Stalwart CalDAV
- [ ] iOS Calendar app syncs via Stalwart CalDAV endpoint
- [ ] Android DAVx5 syncs via Stalwart CalDAV endpoint
- [ ] Remove custom DAV client code from worker (lib/dav/)
- [ ] Test: Create event in Web → appears on iPhone within 1 minute

### Story 4.2: Migrate Contacts to Stalwart CardDAV

As a team member,
I want contacts powered by Stalwart's native CardDAV,
So that contacts sync across all devices without custom code.

**Acceptance Criteria:**
- [ ] Contacts Web UI fetches from Stalwart CardDAV (via API proxy)
- [ ] Create/edit/delete contacts in Web UI → writes to Stalwart CardDAV
- [ ] iOS/Android contacts app syncs via Stalwart CardDAV
- [ ] Remove custom CardDAV client code from worker
- [ ] Test: Add contact in Web → appears on phone

### Story 4.3: Migrate Email Rules to Sieve

As a team member,
I want email rules executed by Stalwart's Sieve engine,
So that rules run at the server level (faster, more reliable).

**Acceptance Criteria:**
- [ ] Existing rules in PostgreSQL → compiled to Sieve scripts
- [ ] Sieve scripts pushed to Stalwart via ManageSieve protocol
- [ ] Rule changes in Web UI → generate Sieve → push to Stalwart
- [ ] Supported actions: move to folder, add label, forward, discard
- [ ] Remove application-layer rules processor from worker
- [ ] Test: Create "move newsletters to folder" rule → verify it works for next incoming email

### Story 4.4: Implement NATS Event Publishing

As a developer (other Lurus services),
I want webmail events published to NATS,
So that my service can react to mail events.

**Acceptance Criteria:**
- [ ] NATS stream `WEBMAIL_EVENTS` created
- [ ] Events published:
  - `webmail.mail.received` — {from, to, subject, message_id, timestamp}
  - `webmail.mail.sent` — {from, to, subject, message_id, channel, timestamp}
  - `webmail.mail.bounced` — {message_id, reason, timestamp}
- [ ] Events published from webmail-api on Stalwart webhook callback
- [ ] Test: Send email → NATS subscriber receives event within 5s

### Story 4.5: Implement Mail Template Support

As a developer,
I want to send templated emails via NATS event,
So that other services can send formatted notifications.

**Acceptance Criteria:**
- [ ] Template storage in PostgreSQL (name, subject_template, body_html_template)
- [ ] NATS consumer: `webmail.mail.send_template` → renders template → sends email
- [ ] Variable substitution: `{{user_name}}`, `{{action_url}}`, etc.
- [ ] Built-in templates: welcome, password_reset, notification
- [ ] Test: Publish NATS event with template_id → email sent with rendered content

---

## Epic 5: Cleanup & Observability

**Goal:** 移除所有废弃组件，建立完整可观测性，确保架构清洁。

**Duration:** 1 week
**Depends on:** Epic 2 (JMAP stable), Epic 3 (AI/PWA done), Epic 4 (DAV/rules migrated)

### Story 5.1: Remove Deprecated Components

As a developer,
I want all unused code and infrastructure removed,
So that the codebase is clean and maintainable.

**Acceptance Criteria:**
- [ ] Remove IMAP sync code: `lib/imap/` (imap-client, imap-idle-sync, imap-delta-fetch, etc.)
- [ ] Remove Typesense: K8s deployment + indexing code + search worker
- [ ] Remove Supabase: All remaining Supabase references, docker-compose supabase stack
- [ ] Remove deprecated PostgreSQL tables (archive migration, don't drop)
- [ ] Remove `@supabase/supabase-js` from all package.json
- [ ] Remove `imapflow` from worker package.json
- [ ] Remove DAV client code (lib/dav/)
- [ ] Build + test pass with zero removed-dependency references
- [ ] `kubectl get pods -n lurus-webmail` shows only: web, api, redis

### Story 5.2: Implement OpenTelemetry Tracing

As a system admin,
I want distributed tracing across the mail delivery pipeline,
So that I can diagnose issues end-to-end.

**Acceptance Criteria:**
- [ ] OTel SDK initialized in both web and api services
- [ ] Key spans instrumented:
  - `email.compose` (user → API)
  - `email.route.decide` (China vs International)
  - `smtp.send` (SMTP transaction)
  - `jmap.request` (JMAP calls to Stalwart)
  - `ai.request` (LLM calls)
  - `push.notify` (Web Push)
- [ ] Traces exported to Jaeger (jaeger.lurus.cn)
- [ ] Trace ID included in structured logs
- [ ] Test: Send email → complete trace visible in Jaeger

### Story 5.3: Create Grafana Dashboard

As a system admin,
I want a Grafana dashboard for lurus-webmail,
So that I can monitor system health at a glance.

**Acceptance Criteria:**
- [ ] Dashboard created at grafana.lurus.cn
- [ ] Panels:
  - Mail sent/received count (24h trend)
  - Delivery success rate by channel (SendCloud vs Stalwart)
  - JMAP request latency (p50, p95, p99)
  - AI feature usage (requests/hour, avg latency)
  - Pod health (CPU, memory, restarts)
  - Redis queue depth
  - Stalwart status (connections, storage)
- [ ] Alert rules:
  - Delivery failure rate > 5% (5min window) → alert
  - Stalwart unreachable → critical alert
  - Queue depth > 100 → warning

### Story 5.4: Update Documentation

As a developer,
I want documentation updated to reflect v2.0 architecture,
So that future sessions can quickly understand the system.

**Acceptance Criteria:**
- [ ] CLAUDE.md updated with v2.0 commands and architecture summary
- [ ] README.md updated (no longer Kurrier fork description)
- [ ] Architecture diagram in _bmad-output reflects current state
- [ ] doc/decisions/ contains ADR entries for key v2.0 decisions
- [ ] K8s manifests have inline comments explaining each component

---

## Implementation Schedule / 实施日程

```
Week  1-2:  Epic 0 — Foundation (tech debt, credentials, DMARC)
Week  3-4:  Epic 1 — Auth Overhaul (remove Supabase, Zitadel direct)
Week  5-7:  Epic 2 — JMAP Core (mail read/write/search/push)
Week  8-9:  Epic 3 — AI + PWA (summarize, categorize, push notifications)
Week  9-10: Epic 4 — DAV Native + Automation (calendar, contacts, Sieve, NATS)
Week 11:    Epic 5 — Cleanup + Observability (remove old, add tracing)
```

**Parallel opportunities:**
- Epic 3 and Epic 4 can run in parallel (independent feature sets)
- Story 0.4 (DMARC) can run in background throughout all phases
- Story 5.3 (Grafana) can start during Epic 2 and evolve incrementally

---

## Definition of Done / 完成标准

每个 Story 完成需满足：

1. **Code**: 实现代码已提交，通过 Biome lint
2. **Tests**: 关键路径有单元测试或集成测试
3. **Deploy**: 已部署到 K3s 并验证功能
4. **Docs**: 相关文档已更新
5. **No regression**: 现有功能不受影响（或明确标注 breaking change）

---

## Risk Register / 风险登记

| Risk | Impact | Phase | Mitigation |
|------|--------|-------|------------|
| Supabase 移除导致 UI 大面积重写 | High | Epic 1 | 先映射所有 Supabase 调用点，逐个替换，feature flag 控制 |
| JMAP 性能不达预期 | Medium | Epic 2 | Story 2.3 先用 feature flag 对比 JMAP vs PostgreSQL 性能 |
| Stalwart OIDC 配置不通 | High | Epic 0 | Story 0.3 作为 blocker，提前验证 |
| AI 延迟影响 UX | Low | Epic 3 | AI 全部异步处理，不阻塞邮件操作 |
| SendCloud 凭据无法获取 | Medium | Epic 0 | 降级方案：所有域名走 Stalwart 直连 |

---

## Future Roadmap (v3.0+) / 长期路线图

| Item | Priority | Description |
|------|----------|-------------|
| Go API Rewrite | P2 | 将 Nitro worker 逐步迁移为 Go 服务，与公司技术栈统一 |
| BIMI Support | P3 | 品牌标识（需注册商标 + VMC 证书） |
| S/MIME Optional | P3 | 可选端到端加密（Stalwart 原生支持） |
| Multi-Tenant | P3 | 为外部用户提供邮件托管 |
| Stalwart ElasticSearch | P3 | 如内建搜索不够，启用 ES 后端 |
| AI Smart Compose | P2 | 实时写作辅助（需 streaming LLM） |
| Natural Language Search | P2 | "上周 Alice 发给我的关于项目进度的邮件" |
