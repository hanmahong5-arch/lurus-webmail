---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: ['lurus.yaml', 'CLAUDE.md', 'doc/plan.md', 'doc/process.md', 'doc/decisions/0001-single-source-of-truth.md', 'project-context.md']
date: 2026-02-02
regenerated: 2026-02-02
author: Anita (via BMAD Analysis)
---

# Product Brief: Lurus Platform
# 产品简报：Lurus 平台

---

## 1. Vision / 愿景

### Problem Statement / 问题陈述

中国中小企业和独立开发者在使用 AI 大模型和量化交易工具时，面临以下核心痛点：

1. **AI 模型访问碎片化**：OpenAI、Anthropic、Google 等多个供应商，各自 API 不兼容，管理混乱
2. **量化交易门槛高**：需要深厚的编程和金融知识，现有工具对非专业用户不友好
3. **企业工具成本高昂**：邮件、文档、存储等基础设施依赖第三方 SaaS，数据主权丧失
4. **运维复杂度**：多服务部署、监控、日志管理需要专业 DevOps 团队

### Vision Statement / 愿景声明

**Lurus 是一个自建的混合云企业平台，为 2 人小团队提供 AI 网关、量化交易、邮件系统和内部工具的统一基础设施，实现数据自主权和运营自动化。**

### Unique Value Proposition / 独特价值主张

| Differentiator | Description |
|----------------|-------------|
| **AI Gateway Unification** | 单一 API 端点访问所有主流 LLM (OpenAI, Anthropic, Google, AWS Bedrock) |
| **Financial-Grade Backtest** | Decimal.js 精度、30+ 指标、680+ 单元测试、多 Agent AI 投资顾问 |
| **Self-Hosted Everything** | 邮件、存储、认证全部自建，数据永远在自己手里 |
| **AI-Native Workflow** | 自然语言策略生成、自动策略发现、工作流编排 |
| **2-Person + AI Team** | AI Code 主导编码，人工审核关键决策，最小团队最大产出 |

---

## 2. Target Users / 目标用户

### User Persona 1: Team Owner (Anita) / 团队所有者

- **角色**: 技术负责人，全栈开发者
- **需求**: 统一管理所有服务，快速迭代新功能，低运维成本
- **痛点**: 一个人要管 7 个服务 + 基础设施
- **使用场景**: 日常开发、部署、监控、数据分析

### User Persona 2: Quantitative Trader / 量化交易用户

- **角色**: 对量化交易感兴趣的投资者
- **需求**: 用自然语言描述策略 → AI 生成代码 → 一键回测 → 查看多维度分析
- **痛点**: 不会编程但想做量化、市面工具太贵或太复杂
- **使用场景**: 策略编写、回测验证、多股验证、AI 投资顾问咨询、热门策略浏览

### User Persona 3: AI API Consumer / AI API 消费者

- **角色**: 使用 LLM API 的开发者/企业
- **需求**: 统一的 OpenAI 兼容 API、用量追踪、成本控制
- **痛点**: 多供应商管理混乱，API Key 分散
- **使用场景**: 通过 api.lurus.cn 调用各种 LLM 模型

---

## 3. Success Metrics / 成功指标

### North Star Metric / 北极星指标

**平台可用性 ≥ 99.5%** - 所有核心服务（API 网关、量化平台、邮件系统）的月度可用率

### Key Metrics / 关键指标

| Category | Metric | Baseline (Feb 2) | Current | Target |
|----------|--------|-------------------|---------|--------|
| **Reliability** | Monthly uptime | ~98% (manual ops) | ~98% | ≥ 99.5% |
| **Gushen** | Backtest execution time (1yr data) | ~3-5s | ~3-5s | < 2s |
| **Gushen** | Strategy validation stock coverage | 10 stocks | 50+ stocks | 50+ stocks |
| **Gushen** | Active strategies (builtin + user) | ~5 | 8+ builtin + user customs | 20+ |
| **Gushen** | Backtest engine test coverage | ~15% | **85%+ (680 tests)** | ≥ 85% |
| **API Gateway** | LLM API response latency (p95) | ~500ms | ~500ms | < 300ms |
| **API Gateway** | Supported model providers | 5 | 5 | 8+ |
| **DevOps** | Deployment frequency | 2-3/week | 2-3/week | Daily |
| **DevOps** | Mean time to recovery | ~30min | ~30min | < 10min |
| **DevOps** | Staging environment | None | ✅ ai-qtrd-staging | Maintained |
| **Testing** | Overall test coverage | ~40% | ~55% | ≥ 70% |
| **Webmail** | Email delivery success rate | N/A (dev) | Beta testing | ≥ 98% |

---

## 4. Core Features by Service / 各服务核心功能

### 4.1 lurus-api (LLM Unified Gateway)

| Feature | Status | Priority |
|---------|--------|----------|
| OpenAI-compatible API relay | ✅ Production | P0 |
| Multi-provider support (OpenAI, Anthropic, Google, Bedrock) | ✅ Production | P0 |
| User authentication (Zitadel OIDC) | ✅ Production | P0 |
| Usage tracking & billing | 🔧 Partial | P1 |
| Multi-tenant SaaS transformation | 📋 Planned | P2 |
| Rate limiting | ✅ Production | P0 |
| Meilisearch full-text search | ✅ Production | P1 |
| Graceful shutdown & lifecycle | ✅ Production | P0 |

### 4.2 lurus-gushen (AI Quantitative Trading)

| Feature | Status | Priority |
|---------|--------|----------|
| Strategy editor (natural language → code) | ✅ Production | P0 |
| Financial-grade backtest engine (85%+ test coverage) | ✅ Production | P0 |
| Multi-stock validation with virtual scroll | ✅ Production | P0 |
| 30+ financial metrics (Sharpe, MDD, etc.) | ✅ Production | P0 |
| Multi-agent AI advisor (11 agents, 7 schools) | ✅ Production | P1 |
| K-line data management (DB + API cascade) | ✅ Production | P0 |
| Strategy workspace (auto-save, undo/redo) | ✅ Production | P1 |
| Stock ranking with CSV export & a11y | ✅ Production | P1 |
| User custom strategy in backtest selector | ✅ Production | P0 |
| Workflow system (multi-step strategy dev) | ✅ Production | P1 |
| Strategy crawler (GitHub discovery) | ✅ Production | P1 |
| Hybrid cache (Redis + in-memory) | ✅ Production | P1 |
| K8s staging environment | ✅ Deployed | P0 |
| Real stock target selection for backtest | 🔧 In Progress | P0 |
| Strategy template library (≥ 5 templates) | 📋 Planned | P1 |
| Paper trading (vnpy) | 📋 Planned | P2 |

### 4.3 lurus-webmail (Unified Communications)

| Feature | Status | Priority |
|---------|--------|----------|
| Email send/receive (IMAP/SMTP) | 🔧 Beta | P1 |
| Self-hosted Stalwart mail server | ✅ Deployed | P0 |
| Calendar | 📋 Planned | P2 |
| Contacts | 📋 Planned | P2 |
| Full-text search (Typesense) | 🔧 Development | P1 |
| China mail relay (SendCloud) | ✅ Configured | P1 |

### 4.4 lurus-switch (Desktop Client)

| Feature | Status | Priority |
|---------|--------|----------|
| LLM provider/model configuration | ✅ Production | P1 |
| Content generation tool | 🔧 Development | P2 |
| Cross-platform (Windows/Mac/Linux) | ✅ Production | P1 |

### 4.5 Supporting Services

| Service | Feature | Status |
|---------|---------|--------|
| lurus-newapi | LLM API management & distribution | ✅ Production |
| lurus-docs | Documentation center | ✅ Production |
| lurus-www | Marketing website + AI chat sidebar | ✅ Production |

---

## 5. Scope & Boundaries / 范围与边界

### In Scope / 范围内

- Self-hosted infrastructure (K3s, PostgreSQL, Redis, NATS, MinIO, Stalwart)
- AI gateway with multi-provider relay
- Quantitative trading platform (strategy → backtest → analysis → validation)
- Workflow-based strategy development pipeline
- Automated strategy discovery and conversion (crawler)
- Unified email system
- Desktop LLM client
- GitOps CI/CD pipeline with staging environments
- Monitoring stack (Grafana, Prometheus, Loki)
- BMAD project management framework

### Out of Scope / 范围外

- Public SaaS offering (currently internal use only)
- Real-money automated trading execution (paper trading only planned)
- Mobile native apps (web-responsive only)
- Multi-region deployment (single cluster)
- Third-party user onboarding (team of 2 + AI only)
- Real-time tick data streaming (daily K-line only)

### Constraints / 约束

1. **Team Size**: 2 humans + AI coding assistants
2. **Budget**: Self-hosted on cloud VMs + office machines (hybrid cloud)
3. **Compliance**: No real-money trading features in production
4. **Network**: Tailscale VPN for inter-node communication

---

## 6. Technical Risks & Mitigations / 技术风险与缓解

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Single PostgreSQL instance failure | Critical | Medium | CNPG operator with automated backup to MinIO |
| K3s master node failure | Critical | Low | Automated snapshots, documented recovery runbook |
| Data loss during backtest | Medium | Low | Decimal.js precision, K-line validation, 680+ tests |
| AI model provider outage | Medium | Medium | Multi-provider fallback in API gateway |
| Security breach via exposed credentials | Critical | Low | K8s secrets, .gitignore enforcement, no creds in code |
| Worker node resource exhaustion (2C/2G) | Medium | High | Move staging to master, monitor alerts, plan upgrade |
| Mail delivery blocked (IP reputation) | Medium | High | SendCloud relay for China domains |
| GitHub crawler rate limiting | Low | Medium | Rate limiter, backoff strategy, caching |

---

## 7. Revenue Model / 收入模型

Currently **internal tool / 内部工具** - no direct revenue.

**Future potential / 未来可能**:
1. LLM API resale (via lurus-newapi quota management)
2. Quantitative strategy marketplace
3. Enterprise self-hosted deployment consulting

---

## 8. Competitive Landscape / 竞争格局

| Competitor | Strength | Lurus Advantage |
|-----------|----------|-----------------|
| 聚宽/优矿 | Mature quant platform, large community | Self-hosted, AI-native strategy gen, no coding required |
| OpenRouter | LLM API aggregation, many providers | Self-hosted, no vendor lock-in, data sovereignty |
| Fastmail | Reliable email hosting | Integrated with other Lurus services, self-hosted |
| Vercel | Next.js hosting, edge network | Full control, no per-request billing, staging env |

**Lurus' moat / 护城河**: 全栈自建 + AI 驱动 + 数据自主权 + 工作流编排 + 策略自动发现，适合追求隐私和控制权的技术团队。
