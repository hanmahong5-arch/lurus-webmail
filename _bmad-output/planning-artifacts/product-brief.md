---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: ['lurus.yaml', 'CLAUDE.md', 'architecture.md', 'prd.md']
date: 2026-02-27
version: 2.0
author: Anita (via BMAD Analysis)
supersedes: product-brief.md v1.0 (2026-02-02)
---

# Product Brief: Lurus Webmail v2.0 — "Stalwart-Native" Renovation
# 产品简报：Lurus Webmail v2.0 — "Stalwart-Native" 改造

---

## 1. Renovation Thesis / 改造核心论点

### Why Renovate / 为什么要改造

当前 lurus-webmail 基于 Kurrier 开源项目 fork，存在三个结构性问题：

1. **架构冗余**: Stalwart 已原生支持 JMAP/CalDAV/CardDAV/WebDAV/全文搜索，但 Worker 仍通过 IMAP 同步数据到 PostgreSQL，再用 Typesense 做搜索 —— 双重存储、双重索引、双重维护。
2. **Supabase 债务**: 为了桥接 Zitadel OIDC，运行着完整的 Supabase Auth 栈（Kong、GoTrue、PostgREST），增加了 4 个额外 Pod 和复杂的认证链路。
3. **上游漂移**: 随着定制越深，与 Kurrier 上游的 merge 能力已名存实亡，但代码中仍保留大量 `kurrier` 命名和上游特有逻辑。

### Core Strategy: "Stalwart-Native" / 核心策略

**让 Stalwart 成为邮件/日历/联系人/存储的唯一数据源，应用层只负责 UI、路由、规则和 AI。**

```
Before: User → Next.js → Supabase → PostgREST → PostgreSQL ← IMAP Sync ← Stalwart
After:  User → Next.js → API Layer → JMAP → Stalwart (source of truth)
                                    → PostgreSQL (app metadata only)
```

---

## 2. Vision / 愿景

### Problem Statement / 问题陈述

自建邮件系统的核心挑战不是"能不能用"，而是"能不能低成本持续维护"。当前架构将简单的邮件操作拆成了 6 步链路（Compose → API → Queue → IMAP → PostgreSQL → Typesense → UI），任何一环故障都影响体验。

### Vision Statement / 愿景声明

**lurus-webmail v2.0 是一个极简架构的自建通信平台：前端通过 JMAP 直连 Stalwart，后端只处理智能路由、AI 辅助和业务规则，实现 2 人团队可持续维护的企业级邮件体验。**

### Unique Value Proposition / 独特价值

| 差异点 | 说明 |
|--------|------|
| **Stalwart-Native** | 邮件数据零冗余，Stalwart = 唯一数据源 |
| **JMAP-First** | 2026 年最先进的邮件协议，比 IMAP 效率提升 20 倍 |
| **AI-Assisted** | 利用已有 LLM 基础设施，实现邮件摘要/智能分类/智能撰写 |
| **Zero Supabase** | 直连 Zitadel OIDC，认证链路从 6 步减至 2 步 |
| **PWA Push** | 无需安装 App，浏览器推送新邮件通知 |

---

## 3. Target Users / 目标用户

| 用户群 | 规模 | 使用频率 | v2.0 新增价值 |
|--------|------|----------|---------------|
| 团队成员 (Anita) | 2 人 | 每日 | AI 摘要、PWA 推送、更快的同步 |
| AI 服务 | 3+ 系统 | 事件驱动 | 标准化邮件 API（via NATS） |
| 移动设备 | 2+ 台 | 每日 | 原生 CalDAV/CardDAV via Stalwart |

---

## 4. Success Metrics / 成功指标

### North Star Metric
**架构组件数减少 50%** — 从当前 8 个独立组件（Web、Worker、Kong、GoTrue、PostgREST、Redis、Typesense、Stalwart）减至 4 个（Web、API、Redis、Stalwart）。

### Key Metrics

| Category | Metric | Current | Target |
|----------|--------|---------|--------|
| Architecture | 独立 Pod 数 | 8+ | 4 |
| Architecture | PostgreSQL 表数 (mail) | 15+ | 5 (settings only) |
| Reliability | 邮件收发成功率 | ~95% | > 99% |
| Delivery | 国内投递率 | 未配置 | > 95% (SendCloud) |
| Performance | 新邮件显示延迟 | 3-5s (IMAP IDLE) | < 1s (JMAP push) |
| Auth | 登录步骤数 | 6 (Zitadel→Supabase→Kong→GoTrue) | 2 (Zitadel→JWT) |
| Ops | 周维护时间 | ~4h | < 1h |
| Security | DMARC policy | p=quarantine | p=reject |

### Anti-Metrics
- 不追求用户增长
- 不追求与 Kurrier 上游同步
- 不追求 S/MIME/PGP 加密（低 ROI）

---

## 5. Scope & Boundaries / 范围与边界

### In Scope / 范围内
- 移除 Supabase Auth 全栈，直连 Zitadel OIDC
- IMAP 同步 → JMAP 直连迁移
- PostgreSQL 从全量存储 → 仅存储应用元数据
- 移除 Typesense → 使用 Stalwart 内建搜索
- AI 功能（邮件摘要、智能分类、智能回复）
- PWA + Web Push 通知
- 邮件认证加固（DMARC p=reject、ARC）
- SendCloud 中国域名路由正式上线
- OpenTelemetry 可观测性
- 所有 kurrier 命名清理

### Out of Scope / 范围外
- Go 重写后端（列入长期路线图，v2.0 保持 TypeScript）
- S/MIME / PGP 端到端加密
- BIMI 品牌标识（需注册商标）
- 多租户 / 外部用户注册
- 独立移动 App（PWA + 原生 DAV 客户端足够）

### Constraints / 约束
1. 2 人团队 + AI 编码
2. 必须保持现有邮件数据不丢失
3. 迁移期间服务不中断（渐进式迁移）
4. 复用现有 K3s 基础设施

---

## 6. Technical Risks / 技术风险

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| JMAP 客户端库不成熟 | Medium | Medium | jmap-jam 已有生产案例；保留 IMAP 回退 |
| Stalwart 单点故障 | Critical | Low | RocksDB 定期备份到 MinIO；文档化恢复流程 |
| Supabase 移除导致数据迁移问题 | High | Medium | 分阶段迁移，先双写后切换 |
| JMAP push 在某些网络下不稳定 | Low | Medium | 降级为轮询 + PWA push 兜底 |
| 国内邮件投递被拦截 | Medium | High | SendCloud 信誉管理 + 定期监控 Google Postmaster |

---

## 7. Competitive Context / 竞争对比

| 对比项 | Gmail/Outlook | Fastmail | Roundcube | lurus-webmail v2.0 |
|--------|--------------|----------|-----------|-------------------|
| 数据自主权 | 无 | 无 | 有 | 有 |
| AI 功能 | 强 | 无 | 无 | 有 (via lurus-api) |
| JMAP 支持 | 无/内部 | 有 | 无 | 有 |
| CalDAV/CardDAV | 有 | 有 | 需插件 | 有 (Stalwart native) |
| 中国投递优化 | 有 | 无 | 无 | 有 (SendCloud) |
| 运维成本 | 零 | 付费 | 中 | 低 (极简架构) |
