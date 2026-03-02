---
stepsCompleted: [init, vision, users, metrics, scope, technical, finalize]
inputDocuments: [product-brief.md v2.0, lurus.yaml, architecture.md v1.0, 2026-industry-research]
workflowType: 'prd'
version: 2.0
supersedes: prd.md v1.0 (2026-02-02)
---

# Product Requirements Document — lurus-webmail v2.0

**Author:** Anita
**Date:** 2026-02-27
**Version:** 2.0
**Status:** Draft — Pending Approval

---

## 1. Vision & Goals / 愿景与目标

### Product Vision
将 lurus-webmail 从 Kurrier fork + Supabase 桥接架构，改造为 **Stalwart-Native 极简架构**：JMAP-first、直连 Zitadel、AI 辅助、PWA 推送。

### Business Goals
1. **架构减负**: 组件数从 8+ 减至 4，周维护时间从 ~4h 降至 < 1h
2. **认证统一**: 移除 Supabase Auth 全栈，直连 Zitadel OIDC
3. **协议升级**: IMAP sync → JMAP 直连，新邮件延迟从 3-5s 降至 < 1s
4. **AI 赋能**: 利用已有 LLM 基础设施实现邮件智能功能
5. **投递可靠**: SendCloud 正式上线 + DMARC p=reject

### Non-Goals
- 不重写后端为 Go（v2.0 保持 TypeScript，Go 迁移列入 v3.0 路线图）
- 不支持 S/MIME/PGP 端到端加密（低 ROI，TLS 传输加密足够）
- 不构建原生移动 App
- 不保持与 Kurrier 上游的 merge 兼容性

---

## 2. User Research / 用户研究

### User Segments

| 用户群 | 规模 | 核心 Job-to-be-Done | v2.0 改进 |
|--------|------|---------------------|-----------|
| 团队成员 | 2 人 | 日常收发邮件、管理日程 | 更快的同步、AI 摘要、离线 PWA |
| AI 服务 | 3+ | 发送通知邮件 | NATS 事件驱动 API |
| 移动设备 | 2+ 台 | 随时查看邮件/日历 | PWA 推送 + 原生 DAV |

### User Journey (v2.0)

```
团队成员日常流程 (改造后):
浏览器访问 mail.lurus.cn (PWA installed)
  → Zitadel OIDC 直接登录 (无 Supabase 中转)
    → JMAP 实时加载收件箱 (< 1s)
      → AI 自动分类邮件 (重要/通知/营销)
      → 长线程自动生成摘要
      → 撰写回复时 AI 智能建议
        → 发送: 自动路由 (国内→SendCloud, 海外→Stalwart)
    → 日历/联系人: Stalwart 原生 CalDAV/CardDAV
    → 新邮件: PWA push notification (无需开着标签页)
```

---

## 3. Success Metrics / 成功指标

### North Star Metric
**月度架构事故数 = 0** — 简化架构后，消除因组件间同步失败导致的事故。

### Supporting Metrics

| Category | Metric | Current | Target | Measurement |
|----------|--------|---------|--------|-------------|
| Architecture | 运行 Pod 数 | 8+ | 4 | kubectl count |
| Architecture | 代码行数 (worker) | ~15,000 | ~5,000 | cloc |
| Performance | 新邮件显示延迟 | 3-5s | < 1s | JMAP push timing |
| Performance | 收件箱首屏加载 | ~2s | < 1s | Lighthouse |
| Reliability | 邮件收发成功率 | ~95% | > 99% | Stalwart logs |
| Delivery | 国内投递率 | 未上线 | > 95% | SendCloud dashboard |
| Security | DMARC policy | quarantine | reject | DNS check |
| Auth | 登录链路跳转数 | 4 | 2 | User flow audit |
| Ops | 周维护时间 | ~4h | < 1h | Manual tracking |
| Observability | 关键路径追踪覆盖 | 0% | 100% | OTel spans |

### Anti-Metrics
- 不追求 Lighthouse PWA 满分
- 不追求 100% 测试覆盖率（关键路径 80% 即可）
- 不追求页面加载 < 200ms（< 1s 即可接受）

---

## 4. Functional Requirements / 功能需求

### FR-01: JMAP Mail Operations / JMAP 邮件操作

**Priority: P0 — Core**

- FR-01.1: 通过 JMAP 协议直接读取 Stalwart 邮箱数据（替代 IMAP sync + PostgreSQL）
- FR-01.2: 通过 JMAP 发送邮件（Stalwart submission）
- FR-01.3: JMAP push 实时通知新邮件（替代 IMAP IDLE）
- FR-01.4: JMAP 增量同步（仅获取变更，替代全量 delta-fetch）
- FR-01.5: 邮件搜索通过 JMAP query（替代 Typesense）
- FR-01.6: 多身份邮件支持（@lurus.cn + 外部账户 via JMAP identity）
- FR-01.7: 邮件标签/分类通过 JMAP Mailbox + keywords
- FR-01.8: 附件上传/下载通过 JMAP Blob
- FR-01.9: 保留 TipTap 富文本编辑器

### FR-02: Smart Mail Routing / 智能邮件路由

**Priority: P0 — Core**

- FR-02.1: 国内域名 (qq/163/126/foxmail/sina/sohu/aliyun 等 50+) 自动通过 SendCloud SMTP relay
- FR-02.2: 国际域名通过 Stalwart 直连 SMTP
- FR-02.3: 路由决策记录结构化日志（域名、通道、投递状态）
- FR-02.4: SendCloud 投递回调状态追踪（送达/退信/打开）

### FR-03: Authentication / 认证

**Priority: P0 — Core**

- FR-03.1: Zitadel OIDC PKCE 直接登录（无 Supabase 中间层）
- FR-03.2: JWT 会话管理（Next.js server-side + httpOnly cookie）
- FR-03.3: Stalwart 账户通过 Zitadel sub 自动创建/关联
- FR-03.4: PostgreSQL RLS 通过 JWT claims 中的 `set_config` 驱动
- FR-03.5: API Key 认证用于服务间调用

### FR-04: Calendar & Contacts / 日历与联系人

**Priority: P1 — Important**

- FR-04.1: 日历/联系人通过 Stalwart 原生 CalDAV/CardDAV（不自建 DAV 服务）
- FR-04.2: Web UI 日历视图（日/周/月）
- FR-04.3: Web UI 联系人管理
- FR-04.4: 移动端通过原生 CalDAV/CardDAV 客户端同步（iOS、Android DAVx5）

### FR-05: AI Features / AI 功能

**Priority: P1 — Important**

- FR-05.1: 长线程自动摘要（通过 lurus-api LLM gateway）
- FR-05.2: 邮件智能分类（重要/通知/营销/社交，基于内容分析）
- FR-05.3: 智能回复建议（3 条简短回复选项）
- FR-05.4: 智能撰写辅助（自动补全、语气调整）
- FR-05.5: 自然语言邮件搜索（"上周 Alice 发给我关于项目进度的邮件"）

### FR-06: PWA & Push / 渐进式 Web 应用

**Priority: P1 — Important**

- FR-06.1: Service Worker 注册 + 离线缓存核心 UI shell
- FR-06.2: Web Push API 新邮件通知（VAPID key）
- FR-06.3: Add to Home Screen 支持（manifest.json）
- FR-06.4: 后台 push：新邮件到达 → JMAP push → NATS event → Web Push endpoint

### FR-07: Email Rules & Automation / 邮件规则

**Priority: P2 — Nice to Have**

- FR-07.1: 保留现有规则引擎（条件匹配 → 自动标记/移动/转发）
- FR-07.2: 规则通过 Stalwart Sieve 脚本执行（替代应用层实现）
- FR-07.3: Web UI 规则管理界面

### FR-08: Mail API for Services / 服务间邮件 API

**Priority: P2 — Nice to Have**

- FR-08.1: NATS 事件驱动邮件发送（其他 Lurus 服务发布事件 → Worker 消费并发送）
- FR-08.2: 邮件模板支持（HTML 模板 + 变量替换）
- FR-08.3: Webhook 回调（投递状态通知）

---

## 5. Non-Functional Requirements / 非功能需求

### NFR-01: Security / 安全

- NFR-01.1: DMARC 升级至 `p=reject`（分阶段：none → quarantine → reject）
- NFR-01.2: ARC 签名支持（转发邮件保留认证链）
- NFR-01.3: SPF strict（`-all`，已配置）
- NFR-01.4: DKIM 2048-bit key rotation 机制
- NFR-01.5: HTTPS only（HSTS header）
- NFR-01.6: Content Security Policy (CSP) header
- NFR-01.7: K8s Secrets 管理（考虑 Sealed Secrets 升级）
- NFR-01.8: Stalwart fail2ban 启用

### NFR-02: Observability / 可观测性

- NFR-02.1: OpenTelemetry 追踪邮件全生命周期（compose → queue → SMTP → delivery）
- NFR-02.2: 结构化 JSON 日志（who/what/result）输出到 stdout（Loki 采集）
- NFR-02.3: Prometheus metrics（邮件发送数、投递延迟、错误率、队列深度）
- NFR-02.4: Grafana dashboard（邮件投递概览、系统健康、Stalwart 状态）
- NFR-02.5: 告警规则（投递失败率 > 5%、Stalwart 不可达、队列积压）

### NFR-03: Deployment / 部署

- NFR-03.1: 保持 K3s + Kustomize + ArgoCD GitOps 流程
- NFR-03.2: Docker 多阶段构建（Bun build → Node.js / Bun runtime）
- NFR-03.3: 镜像推送到 GHCR
- NFR-03.4: 零停机部署（rolling update）

### NFR-04: Performance / 性能

- NFR-04.1: 收件箱首屏加载 < 1s
- NFR-04.2: 邮件列表虚拟滚动（10,000+ 封无卡顿）
- NFR-04.3: JMAP 批量请求优化（单次 HTTP 获取邮箱 + 消息 + 线程）
- NFR-04.4: Redis 缓存 JMAP session 和常用查询结果

### NFR-05: Maintainability / 可维护性

- NFR-05.1: 清除所有 `kurrier` 命名残留
- NFR-05.2: 代码文档使用英文注释
- NFR-05.3: 关键路径测试覆盖 ≥ 80%
- NFR-05.4: Biome lint + format 强制执行

---

## 6. Technical Decisions / 技术决策

| Decision | v1.0 | v2.0 | Rationale |
|----------|------|------|-----------|
| 邮件协议 | IMAP (ImapFlow) | **JMAP (jmap-jam)** | 20x 效率提升，内建 push，HTTP 原生 |
| 认证 | Supabase Auth (Kong+GoTrue) | **Zitadel OIDC 直连** | 消除 4 个 Pod，认证链路简化 |
| 邮件数据存储 | PostgreSQL (Drizzle) | **Stalwart (RocksDB)** | 消除双重存储，Stalwart = 唯一数据源 |
| 搜索引擎 | Typesense | **Stalwart 内建搜索** | 减少组件，Stalwart 全文搜索足够 |
| 日历/联系人 | Custom DAV client | **Stalwart 原生 CalDAV/CardDAV** | 零额外代码，Stalwart 完整支持 |
| 任务队列 | BullMQ (Redis) | **BullMQ (Redis)** | 保留，成熟可靠 |
| 事件总线 | 无 | **NATS (WEBMAIL_EVENTS)** | 与公司基础设施统一，跨服务通信 |
| 通知 | 无 | **Web Push (VAPID)** | PWA 标准，无需安装 App |
| AI | 无 | **lurus-api LLM gateway** | 复用已有基础设施 |
| 可观测性 | Pino logs | **OpenTelemetry + Pino** | 分布式追踪，端到端可见性 |
| 前端框架 | Next.js 16 + Mantine | **保留** | 成熟可靠，无需变更 |
| 包管理 | Bun | **保留** | 性能好，公司标准 |

---

## 7. Data Migration Strategy / 数据迁移策略

### Phase 1: 双写期
- PostgreSQL 继续存储邮件数据
- 新增 JMAP 读取路径（通过 feature flag 切换）
- 验证 JMAP 数据与 PostgreSQL 数据一致

### Phase 2: 读切换
- 默认从 JMAP 读取
- PostgreSQL 作为降级回退
- 监控切换后的性能和正确性

### Phase 3: 写切换
- 停止 IMAP sync 写入 PostgreSQL
- 仅保留 app metadata 表（settings, rules, api_keys, webhooks, ai_metadata）
- 归档历史邮件数据表（不删除，标记为 deprecated）

### Phase 4: 清理
- 移除 IMAP sync 代码
- 移除 Typesense
- 移除 Supabase Auth 栈
- 清理 PostgreSQL deprecated 表

---

## 8. Release Plan / 发布计划

| Phase | Name | Duration | Key Deliverables |
|-------|------|----------|-----------------|
| 0 | Foundation | 2 weeks | Tech debt cleanup, credentials, DMARC, kurrier rename |
| 1 | Auth Overhaul | 2 weeks | Remove Supabase, direct Zitadel OIDC, JWT RLS |
| 2 | JMAP Core | 3 weeks | JMAP mail read/write/search, remove IMAP sync |
| 3 | AI & Push | 2 weeks | AI summarize/classify, PWA, Web Push |
| 4 | DAV Native | 1 week | Stalwart CalDAV/CardDAV, remove custom DAV code |
| 5 | Cleanup | 1 week | Remove Typesense/Supabase pods, OTel, dashboards |

**Total estimated: ~11 weeks**

---

## 9. Dependencies / 依赖

| Dependency | Type | Status | Action Needed |
|------------|------|--------|---------------|
| Stalwart JMAP | 核心 | Running | Verify JMAP endpoint accessible |
| Stalwart CalDAV/CardDAV | 核心 | Running | Verify DAV endpoints |
| Zitadel | 共享基础设施 | Running | Create webmail OIDC client |
| SendCloud | 外部 SaaS | Configured | Configure API credentials |
| lurus-api (LLM) | 内部服务 | Running | Define AI prompt templates |
| NATS | 共享基础设施 | Running | Create WEBMAIL_EVENTS stream |
| jmap-jam | npm package | Available | Evaluate + integrate |
| Redis | Per-namespace | Running | No change |

---

## 10. Open Questions / 待定事项

1. ~~Zitadel Client ID/Secret~~ → Phase 1 解决
2. ~~SendCloud API 凭据~~ → Phase 0 解决
3. Stalwart JMAP endpoint 是否需要额外网络策略？
4. AI 功能使用哪个 LLM 模型？（建议 Claude Haiku 4.5 for speed/cost）
5. JMAP push 通过 EventSource 还是 WebSocket？（Stalwart 支持两者）
6. 现有 PostgreSQL 邮件数据是否需要迁移到 Stalwart？（建议不迁移，Stalwart 已有通过 IMAP 收到的数据）
