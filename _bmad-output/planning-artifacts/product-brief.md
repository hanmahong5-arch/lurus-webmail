---
stepsCompleted: [init, vision, market, users, scope, finalize]
inputDocuments: [lurus.yaml, k8s/, package.json, README.md]
date: 2026-02-02
author: Anita
---

# Product Brief: lurus-webmail

## 1. Product Vision / 产品愿景

### Problem Statement

Lurus 团队（2 人 + AI）需要一个自建、可控的企业通信平台，替代 SaaS 邮件服务，实现：
- 数据主权：所有邮件、日历、联系人、文件存储在自有基础设施
- 无供应商锁定：不依赖 Google Workspace / Microsoft 365
- 中国特殊需求：国内邮件投递（通过 SendCloud 中继）+ 海外直连

### Solution

基于开源 [Kurrier](https://github.com/kurrier-org/kurrier) 项目 fork 定制的自托管 webmail 平台，整合公司现有 K3s 基础设施，提供统一的邮件、日历、联系人和存储服务。

### Core Value Proposition

| 维度 | 价值 |
|------|------|
| 数据主权 | 全部数据运行在公司自有 K3s 集群 |
| 成本 | 零 SaaS 订阅费，利用现有基础设施 |
| 定制化 | 可针对中国网络环境深度定制 |
| 统一身份 | 接入 Zitadel SSO，与其他 Lurus 服务统一认证 |

## 2. Target Users / 目标用户

### Primary Users
- **Lurus 团队成员**（2 人）：日常收发邮件、管理日历和联系人
- **AI 服务账户**：通过 API 发送通知邮件（LLM 网关告警、系统通知）

### User Personas

**Persona 1: 团队成员 (Anita / 同事)**
- 需要在 mail.lurus.cn 上收发邮件
- 需要日历同步到手机（CalDAV）
- 需要联系人同步（CardDAV）
- 偶尔需要共享文件（Drive 功能）

**Persona 2: 系统服务**
- lurus-api 需要发送 quota 告警邮件
- gushen 需要发送量化交易通知
- 需要通过 API 而非 SMTP 调用

## 3. Market Context / 市场定位

### Competitive Landscape

| 方案 | 优势 | 劣势 |
|------|------|------|
| Google Workspace | 功能完善、生态丰富 | 月费高、数据在境外、中国访问不稳定 |
| Microsoft 365 | 企业级功能 | 成本高、厂商锁定 |
| Roundcube | 轻量自建 | 仅邮件、无日历联系人、UI 过时 |
| **lurus-webmail** | 全栈自建、SSO 集成 | 维护成本由团队承担 |

### Differentiation
- 唯一一个整合 Zitadel SSO + Stalwart + 中国 SendCloud 中继的方案
- 唯一一个运行在公司现有 K3s 集群上的零增量成本方案

## 4. Feature Scope / 功能范围

### MVP Features (Current)
- [x] IMAP/SMTP 收发邮件（通过 Stalwart）
- [x] Web UI 邮件客户端（Next.js）
- [x] 多身份邮件支持
- [x] 标签和搜索（Typesense）
- [x] 中国国内邮件中继（SendCloud）
- [x] CalDAV 日历同步
- [x] CardDAV 联系人同步
- [x] Zitadel SSO 登录
- [x] K8s 部署 + ArgoCD GitOps

### Future Features
- [ ] Drive 文件存储（WebDAV / MinIO 集成）
- [ ] 邮件 API（供其他 Lurus 服务调用）
- [ ] 移动端 PWA 优化
- [ ] 邮件模板和自动回复
- [ ] 共享邮箱

## 5. Technical Constraints / 技术约束

- **基础设施**: 复用公司 K3s 集群，PostgreSQL (CNPG)，Redis
- **网络**: 国内服务器需要 v2ray 代理访问 GitHub；国内邮件需 SendCloud 中继
- **团队规模**: 2 人 + AI，维护负担必须最小化
- **SSO**: 必须接入 Zitadel (auth.lurus.cn)
- **上游同步**: 保持与 kurrier 上游的 merge 能力

## 6. Success Metrics / 成功指标

| 指标 | 目标 |
|------|------|
| 邮件收发成功率 | > 99% |
| 国内邮件投递率（qq.com, 163.com） | > 95% |
| 日历/联系人同步 | iOS + Android 正常工作 |
| SSO 登录 | 一键跳转无需二次输入密码 |
| 系统可用性 | > 99.5%（月度） |
| 维护时间 | < 2 小时/周 |

## 7. Risks / 风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 上游 kurrier 停更 | 无安全补丁 | Fork 后自维护核心安全逻辑 |
| SendCloud 封禁 | 国内邮件无法投递 | 备选 AliDM 或自建 IP 信誉 |
| Stalwart 稳定性 | 邮件丢失 | PostgreSQL 持久化 + 定期备份 |
| 团队人力不足 | 功能延期 | AI 辅助开发 + 优先级严格管理 |
