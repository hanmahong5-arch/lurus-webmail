---
stepsCompleted: [init, vision, users, metrics, scope, finalize]
inputDocuments: [product-brief.md, lurus.yaml, k8s/, README.md]
workflowType: 'prd'
---

# Product Requirements Document - lurus-webmail

**Author:** Anita
**Date:** 2026-02-02
**Version:** 1.0
**Status:** Active

---

## 1. Vision & Goals / 愿景与目标

### Product Vision
为 Lurus 团队提供自建的、隐私优先的统一通信平台，涵盖邮件、日历、联系人和文件存储，运行在自有 K3s 基础设施上，实现数据主权和零 SaaS 依赖。

### Business Goals
1. **消除 SaaS 依赖**: 不使用 Google Workspace / Microsoft 365
2. **数据合规**: 所有通信数据存储在自有服务器
3. **成本优化**: 利用现有 K3s 集群，零增量基础设施成本
4. **统一认证**: 接入 Zitadel SSO，与全部 Lurus 服务统一身份

### Non-Goals
- 不为外部客户提供邮件托管服务
- 不构建独立的移动 App（使用原生 CalDAV/CardDAV 客户端）
- 不替代 Stalwart 邮件服务器（Stalwart 作为底层 MTA 保留）

---

## 2. User Research / 用户研究

### User Segments

| 用户群 | 规模 | 使用频率 | 关键需求 |
|--------|------|----------|----------|
| 团队成员 | 2 人 | 每日 | 收发邮件、日历、联系人 |
| AI 服务 | 3+ 系统 | 事件驱动 | API 发送通知邮件 |

### User Journey Map

```
团队成员日常流程:
浏览器访问 mail.lurus.cn
  → Zitadel SSO 自动登录
    → 查看收件箱 (IMAP via Stalwart)
      → 撰写/回复邮件
        → 国内收件人 → SendCloud 中继
        → 海外收件人 → Stalwart 直连
    → 查看日历 (CalDAV)
    → 管理联系人 (CardDAV)
```

### Jobs-to-be-Done

| Job | 当前解决方案 | lurus-webmail 方案 |
|-----|-------------|-------------------|
| 收发企业邮件 | 第三方邮件 | Stalwart + Web UI |
| 日历管理 | 手机本地日历 | CalDAV 全设备同步 |
| 联系人管理 | 手动维护 | CardDAV 全设备同步 |
| 系统通知邮件 | 无 / 手动 | Worker API 自动发送 |

---

## 3. Success Metrics / 成功指标

### North Star Metric
**日活邮件处理量** — 团队成员每天通过平台处理的邮件数（收+发）

### Supporting Metrics

| Category | Metric | Target | Measurement |
|----------|--------|--------|-------------|
| Reliability | 邮件收发成功率 | > 99% | Stalwart logs + Worker metrics |
| Delivery | 国内投递率 (qq/163/126) | > 95% | SendCloud dashboard |
| Sync | CalDAV/CardDAV 同步成功率 | > 99% | Client sync status |
| Auth | SSO 登录成功率 | > 99.5% | Zitadel audit logs |
| Uptime | 月度可用性 | > 99.5% | Prometheus/Grafana |
| Ops | 周维护时间 | < 2h | 人工记录 |

### Anti-Metrics (Things We Don't Optimize For)
- 不追求用户增长（固定 2 人团队）
- 不追求功能数量（够用即可）
- 不追求页面加载速度 < 200ms（< 2s 即可接受）

---

## 4. Scope Definition / 范围定义

### Functional Requirements

#### FR-01: Email / 邮件
- FR-01.1: 通过 Web UI 收发邮件（IMAP/SMTP via Stalwart）
- FR-01.2: 多身份邮件支持（@lurus.cn + 外部 IMAP 账户）
- FR-01.3: 邮件标签、搜索（Typesense 全文搜索）
- FR-01.4: 附件上传/下载
- FR-01.5: 富文本编辑器（TipTap）
- FR-01.6: 中国国内邮件通过 SendCloud 中继投递
- FR-01.7: IMAP IDLE 实时推送新邮件

#### FR-02: Calendar / 日历
- FR-02.1: CalDAV 日历同步（iOS/Android/Thunderbird）
- FR-02.2: Web UI 日历视图（查看/创建/编辑事件）

#### FR-03: Contacts / 联系人
- FR-03.1: CardDAV 联系人同步
- FR-03.2: Web UI 联系人管理

#### FR-04: Authentication / 认证
- FR-04.1: Zitadel OIDC SSO 登录
- FR-04.2: Session 管理（Supabase Auth）
- FR-04.3: Row Level Security (PostgreSQL RLS)

#### FR-05: Search / 搜索
- FR-05.1: Typesense 全文邮件搜索
- FR-05.2: 联系人搜索
- FR-05.3: 标签过滤

#### FR-06: API / 接口 (Future)
- FR-06.1: 供 Lurus 其他服务调用的邮件发送 API
- FR-06.2: Webhook 回调支持

### Non-Functional Requirements

#### NFR-01: Deployment / 部署
- NFR-01.1: K3s + Kustomize 部署
- NFR-01.2: ArgoCD GitOps 自动同步
- NFR-01.3: GitHub Actions 构建 Docker 镜像到 GHCR
- NFR-01.4: 多架构镜像 (amd64 + arm64)

#### NFR-02: Infrastructure / 基础设施
- NFR-02.1: 复用公司 CNPG PostgreSQL (lurus-pg-rw)
- NFR-02.2: 独立 Redis 实例（同 namespace）
- NFR-02.3: Stalwart 在独立 mail namespace
- NFR-02.4: Typesense 独立部署

#### NFR-03: Security / 安全
- NFR-03.1: 全链路 HTTPS (Traefik IngressRoute)
- NFR-03.2: PostgreSQL RLS 行级安全
- NFR-03.3: JWT 签名验证（Supabase 兼容）
- NFR-03.4: Secrets 通过 K8s Secret 管理

#### NFR-04: Observability / 可观测性
- NFR-04.1: Prometheus metrics 暴露
- NFR-04.2: Grafana dashboard
- NFR-04.3: 日志输出到 stdout（Loki 采集）

#### NFR-05: Maintainability / 可维护性
- NFR-05.1: 保持与 kurrier 上游的 merge 能力
- NFR-05.2: Monorepo (pnpm workspace) 统一管理
- NFR-05.3: Biome 代码质量检查
- NFR-05.4: 测试覆盖 (Vitest)

---

## 5. Technical Decisions / 技术决策

| Decision | Choice | Rationale |
|----------|--------|-----------|
| 前端框架 | Next.js + React | 上游 kurrier 选型，SSR 支持好 |
| 后端 Worker | Nitro (Node.js) | 上游选型，IMAP/SMTP 处理 |
| 数据库 | PostgreSQL (CNPG) | 公司统一基础设施 |
| 搜索引擎 | Typesense | 轻量级，上游选型 |
| 邮件服务器 | Stalwart | Rust 实现，高性能，内存安全 |
| SSO | Zitadel OIDC | 公司统一认证 |
| 国内中继 | SendCloud | 中国邮件投递信誉好 |
| 部署 | K3s + ArgoCD | 公司统一 GitOps 流程 |
| 包管理 | pnpm (monorepo) | 上游选型，高效磁盘利用 |

---

## 6. Release Plan / 发布计划

### Phase 1: Core Email (Current - v1.x) ✅
- 邮件收发、多身份、标签、搜索
- Stalwart + SendCloud 中继
- K8s 部署 + ArgoCD
- Zitadel SSO 集成

### Phase 2: Calendar & Contacts (Next - v2.x)
- CalDAV/CardDAV 完整集成
- Web UI 日历和联系人视图
- 移动设备同步验证

### Phase 3: API & Automation (v3.x)
- 邮件发送 API（供 lurus-api, gushen 调用）
- Webhook 回调
- 邮件模板

### Phase 4: Drive & Storage (v4.x)
- 文件存储（MinIO 集成）
- WebDAV 支持
- 共享文件夹

---

## 7. Dependencies / 依赖

| Dependency | Type | Owner | Status |
|------------|------|-------|--------|
| Stalwart Mail Server | 外部 | 独立 namespace: mail | Deployed ✅ |
| PostgreSQL (CNPG) | 共享基础设施 | database node | Running ✅ |
| Redis | Per-namespace | lurus-webmail | Running ✅ |
| Typesense | Per-namespace | lurus-webmail | Running ✅ |
| Zitadel | 共享基础设施 | auth.lurus.cn | Running ✅ |
| SendCloud | 外部 SaaS | sendcloud.net | Configured ✅ |
| Traefik | 共享 ingress | kube-system | Running ✅ |
| ArgoCD | GitOps | argocd namespace | Running ✅ |

---

## 8. Open Questions / 待定事项

1. Zitadel Client ID/Secret 是否已创建？（secrets.yaml 中仍为 TODO）
2. SendCloud API 凭据是否已配置？
3. Stalwart admin 密码是否已设置？
4. CalDAV/CardDAV 是否需要通过 Baikal 代理还是 Stalwart 原生支持？
5. Drive 功能是否计划使用公司 MinIO (100.79.24.40) 还是独立存储？
