---
stepsCompleted: [validate-prereqs, design-epics, create-stories, final-validate]
inputDocuments: [prd.md, architecture.md, product-brief.md]
---

# lurus-webmail - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for lurus-webmail, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR-01: Email (收发邮件, 多身份, 标签, 搜索, 附件, SendCloud 中继, IMAP IDLE)
- FR-02: Calendar (CalDAV 同步, Web UI)
- FR-03: Contacts (CardDAV 同步, Web UI)
- FR-04: Authentication (Zitadel SSO, Session, RLS)
- FR-05: Search (Typesense 全文搜索)
- FR-06: API (邮件发送 API, Webhook) [Future]

### Non-Functional Requirements

- NFR-01: Deployment (K3s, ArgoCD, GHCR)
- NFR-02: Infrastructure (CNPG, Redis, Stalwart, Typesense)
- NFR-03: Security (HTTPS, RLS, JWT, Secrets)
- NFR-04: Observability (Prometheus, Grafana, Loki)
- NFR-05: Maintainability (upstream merge, monorepo, tests)

### FR Coverage Map

| Requirement | Epic |
|-------------|------|
| FR-01 (Email) | Epic 1 (partially done), Epic 5 |
| FR-02 (Calendar) | Epic 3 |
| FR-03 (Contacts) | Epic 3 |
| FR-04 (Auth) | Epic 2 |
| FR-05 (Search) | Epic 1 (done) |
| FR-06 (API) | Epic 4 |
| NFR-01..05 | Epic 5 (Ops) |

## Epic List

| # | Epic | Status | Priority |
|---|------|--------|----------|
| 1 | Core Email Platform | In Progress | P0 |
| 2 | SSO & Security Hardening | Not Started | P0 |
| 3 | Calendar & Contacts | Not Started | P1 |
| 4 | Mail API for Lurus Services | Not Started | P2 |
| 5 | Ops & Tech Debt Cleanup | Not Started | P1 |

---

## Epic 1: Core Email Platform

**Goal:** Deliver a fully functional webmail experience with IMAP/SMTP, search, labels, and China mail relay.

**Status:** Largely implemented. Key gaps: IMAP IDLE stability, SendCloud credential configuration.

### Story 1.1: Validate IMAP IDLE Real-time Sync

As a team member,
I want new emails to appear in my inbox within seconds,
So that I don't miss time-sensitive communications.

**Acceptance Criteria:**

**Given** the worker is connected to Stalwart via IMAP IDLE
**When** a new email arrives at Stalwart
**Then** the email appears in the web UI within 5 seconds
**And** no manual refresh is needed

### Story 1.2: Configure SendCloud Relay for China Domains

As a team member,
I want emails to qq.com/163.com recipients delivered reliably,
So that I can communicate with Chinese business contacts.

**Acceptance Criteria:**

**Given** SendCloud API credentials are configured in K8s secrets
**When** I send an email to a qq.com address
**Then** the email is routed through SendCloud SMTP relay
**And** delivery status is tracked in the worker logs

### Story 1.3: Verify Stalwart DKIM/SPF/DMARC

As a system admin,
I want lurus.cn email to pass all authentication checks,
So that outgoing email is not marked as spam.

**Acceptance Criteria:**

**Given** Stalwart is configured with DKIM keys
**When** I send email from @lurus.cn
**Then** DKIM signature is valid
**And** SPF check passes
**And** DMARC alignment passes

---

## Epic 2: SSO & Security Hardening

**Goal:** Complete Zitadel SSO integration and harden security configuration.

### Story 2.1: Configure Zitadel OIDC Client

As a system admin,
I want Zitadel SSO configured for mail.lurus.cn,
So that team members can login with their unified identity.

**Acceptance Criteria:**

**Given** a Zitadel Application is created with PKCE
**When** I set the Client ID/Secret in K8s secrets
**Then** visiting mail.lurus.cn redirects to Zitadel login
**And** after auth, user is redirected back with a valid session
**And** the callback URL is https://mail.lurus.cn/api/kong/auth/v1/callback

### Story 2.2: Configure Stalwart Admin Password

As a system admin,
I want the Stalwart admin password set to a secure value,
So that the mail server management interface is protected.

**Acceptance Criteria:**

**Given** a secure password is generated
**When** it's configured in stalwart K8s secret
**Then** Stalwart admin UI requires authentication
**And** the password is not the default value

### Story 2.3: Audit K8s Secrets for TODO Values

As a system admin,
I want all TODO placeholder values in secrets.yaml replaced,
So that no services are running with missing credentials.

**Acceptance Criteria:**

**Given** I review k8s/secrets.yaml
**When** all TODO values are identified
**Then** each is replaced with actual credentials
**And** no TODO string remains in deployed secrets

---

## Epic 3: Calendar & Contacts

**Goal:** Deliver CalDAV calendar sync and CardDAV contacts sync across all devices.

### Story 3.1: Verify CalDAV Sync with iOS

As a team member,
I want my calendar events synced to my iPhone,
So that I can see meetings on my mobile device.

**Acceptance Criteria:**

**Given** CalDAV is configured in iOS Settings
**When** I create a calendar event in web UI
**Then** it appears on iPhone within 1 minute
**And** editing on iPhone syncs back to web UI

### Story 3.2: Verify CardDAV Sync with iOS

As a team member,
I want my contacts synced to my iPhone,
So that I have consistent contact info across devices.

**Acceptance Criteria:**

**Given** CardDAV is configured in iOS Settings
**When** I add a contact in web UI
**Then** it appears in iPhone contacts
**And** phone numbers are correctly formatted

### Story 3.3: Calendar Web UI

As a team member,
I want to view and manage my calendar in the web UI,
So that I don't need a separate calendar app.

**Acceptance Criteria:**

**Given** I navigate to the calendar section
**When** the page loads
**Then** I see my calendar events in day/week/month view
**And** I can create, edit, and delete events

---

## Epic 4: Mail API for Lurus Services

**Goal:** Expose a programmatic mail API for other Lurus services to send notifications.

### Story 4.1: Design Mail API Spec

As a developer,
I want a documented API for sending email,
So that lurus-api and gushen can send notifications.

**Acceptance Criteria:**

**Given** the API spec is designed
**When** reviewed against lurus-api notification requirements
**Then** the spec covers: send email, template support, batch send
**And** authentication uses internal service token

### Story 4.2: Implement Mail Send API

As a service (lurus-api),
I want to call a REST API to send email,
So that I can notify users about quota exhaustion.

**Acceptance Criteria:**

**Given** a valid service token
**When** POST /api/mail/send with recipient, subject, body
**Then** email is queued and sent within 30 seconds
**And** 200 OK is returned with message ID

### Story 4.3: Implement Webhook Callbacks

As a developer,
I want webhook notifications for mail events,
So that services can react to delivery status.

**Acceptance Criteria:**

**Given** a webhook URL is configured
**When** an email is delivered/bounced/opened
**Then** an HTTP POST is sent to the webhook URL
**And** the payload includes event type, message ID, timestamp

---

## Epic 5: Ops & Tech Debt Cleanup

**Goal:** Clean up naming inconsistencies, improve observability, and reduce technical debt.

### Story 5.1: Rename kurrier References to lurus-webmail

As a developer,
I want all internal kurrier references updated,
So that the codebase reflects the actual project identity.

**Acceptance Criteria:**

**Given** a list of kurrier references (Redis prefix, JWT issuer, default sender, init-db.sql)
**When** each is updated to lurus-webmail equivalents
**Then** no functional breakage occurs
**And** Redis key migration is handled gracefully

### Story 5.2: Set Up Monitoring Dashboard

As a system admin,
I want a Grafana dashboard for lurus-webmail,
So that I can monitor email delivery and system health.

**Acceptance Criteria:**

**Given** Prometheus metrics are exposed by web and worker
**When** I open Grafana
**Then** I see: mail sent/received counts, delivery latency, error rates, pod health

### Story 5.3: Resolve Cross-Node DNS Issue

As a system admin,
I want K3s cross-node DNS working reliably,
So that services don't need hardcoded ClusterIP workarounds.

**Acceptance Criteria:**

**Given** the current ClusterIP workaround in ArgoCD
**When** the root cause is identified and fixed
**Then** DNS resolution works from all nodes
**And** ClusterIP hardcoding can be removed

### Story 5.4: Set Up Automated Backup

As a system admin,
I want automated backups of the webmail database,
So that data is recoverable in case of failure.

**Acceptance Criteria:**

**Given** CNPG backup is configured
**When** backup runs on schedule
**Then** backups are stored in MinIO (pg-backups-v2 bucket)
**And** recovery procedure is documented and tested
