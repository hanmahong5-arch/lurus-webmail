# Stalwart Mail Server - Local Development Guide

本文档介绍如何在本地搭建完整的邮件测试环境。
This document explains how to set up a complete email testing environment locally.

## Prerequisites

- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- Node.js 20+ with Bun
- PowerShell 7+ (Windows) or Bash (Linux/macOS)

## Quick Start

### 1. Start Local Stalwart

```bash
cd lurus-webmail
docker compose -f deploy/stalwart/docker-compose.yml up -d
```

Wait for the container to be healthy:

```bash
docker compose -f deploy/stalwart/docker-compose.yml logs -f stalwart
```

### 2. Create Test User Account

```bash
# Create test user via Stalwart API
curl -X POST http://localhost:8080/api/principal \
  -u admin:changeme \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "testuser",
    "type": "individual",
    "secrets": ["test123"],
    "emails": ["testuser@mail.lurus.local"]
  }'
```

### 3. Verify Connection

```bash
# Test SMTP (port 587)
curl -v telnet://localhost:587

# Test IMAP (port 143)
curl -v telnet://localhost:143

# Test HTTP API
curl http://localhost:8080/healthz
```

### 4. Run Integration Tests

```bash
cd lurus-webmail

# Set test environment
export STALWART_TEST_HOST=localhost
export STALWART_TEST_SMTP_PORT=587
export STALWART_TEST_IMAP_PORT=143

# Run integration tests
npx vitest run apps/worker/__tests__/integration/
```

## Environment Variables

For local development, create `.env.local` in `apps/worker/`:

```env
# Stalwart (local Docker)
STALWART_SMTP_HOST=localhost
STALWART_SMTP_PORT=587
STALWART_API_URL=http://localhost:8080
STALWART_ADMIN_USER=admin
STALWART_ADMIN_PASSWORD=changeme

# SendCloud (optional - skip for local testing)
# SENDCLOUD_API_USER=your-api-user
# SENDCLOUD_API_KEY=your-api-key
SENDCLOUD_HOST=smtp.sendcloud.net
SENDCLOUD_PORT=587
```

## Test Scenarios

### Scenario 1: Send Local Email

```typescript
// Using nodemailer
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: 'localhost',
  port: 587,
  secure: false,
  auth: {
    user: 'testuser@mail.lurus.local',
    pass: 'test123',
  },
  tls: { rejectUnauthorized: false },
});

await transporter.sendMail({
  from: 'testuser@mail.lurus.local',
  to: 'testuser@mail.lurus.local',
  subject: 'Test Email',
  text: 'Hello from local Stalwart!',
});
```

### Scenario 2: IMAP Sync

```typescript
// Using ImapFlow
import { ImapFlow } from 'imapflow';

const client = new ImapFlow({
  host: 'localhost',
  port: 143,
  secure: false,
  auth: {
    user: 'testuser@mail.lurus.local',
    pass: 'test123',
  },
  tls: { rejectUnauthorized: false },
});

await client.connect();
const mailboxes = await client.list();
console.log('Mailboxes:', mailboxes);
await client.logout();
```

### Scenario 3: Routing Test

```typescript
// Test router logic (no actual sending)
import { routeEmail, classifyRecipients } from './lib/smtp/router';

// China recipients -> SendCloud
const route1 = routeEmail(['user@qq.com', 'user@163.com']);
console.log(route1.channel); // 'sendcloud'

// International -> Stalwart
const route2 = routeEmail(['user@gmail.com']);
console.log(route2.channel); // 'stalwart'

// Mixed -> SendCloud (China takes priority)
const route3 = routeEmail(['user@gmail.com', 'user@qq.com']);
console.log(route3.channel); // 'sendcloud'
```

## Stalwart Admin UI

Access the admin interface at http://localhost:8080

Default credentials:
- Username: `admin`
- Password: `changeme`

From here you can:
- Create/manage user accounts
- View mail queues
- Configure DKIM keys
- Monitor server status

## Docker Compose Commands

```bash
# Start
docker compose -f deploy/stalwart/docker-compose.yml up -d

# View logs
docker compose -f deploy/stalwart/docker-compose.yml logs -f

# Stop
docker compose -f deploy/stalwart/docker-compose.yml down

# Stop and remove volumes (reset all data)
docker compose -f deploy/stalwart/docker-compose.yml down -v

# Restart
docker compose -f deploy/stalwart/docker-compose.yml restart
```

## Troubleshooting

### Port conflicts

If ports 25, 587, or 143 are in use:

```bash
# Check what's using the port
netstat -ano | findstr :587  # Windows
lsof -i :587                  # Linux/macOS

# Modify ports in deploy/stalwart/docker-compose.yml
```

### Connection refused

1. Check container is running: `docker ps`
2. Check container logs: `docker compose logs stalwart`
3. Verify ports are exposed: `docker port stalwart-dev`

### TLS certificate errors

Local Stalwart uses self-signed certificates. Add these options:

```typescript
// nodemailer
tls: { rejectUnauthorized: false }

// ImapFlow
tls: { rejectUnauthorized: false }
```

### SMTP authentication failed

1. Verify user exists: `curl -u admin:changeme http://localhost:8080/api/principal/testuser`
2. Check password is correct
3. Ensure auth mechanisms are enabled in config.toml

## Running Full Worker Locally

```bash
cd lurus-webmail

# Install dependencies
bun install

# Start local services (Redis, PostgreSQL - if not using K8s)
# ... (depends on your local setup)

# Start worker with local env
cd apps/worker
bun run dev
```

## Next Steps

After local testing is successful:

1. Configure DNS records (see `scripts/verify-dns.ps1`)
2. Deploy to K8s: `./scripts/deploy-stalwart.ps1 -AdminPassword "secure-password"`
3. Update production secrets in `k8s/secrets.yaml`
4. Restart webmail worker

## References

- [Stalwart Documentation](https://stalw.art/docs/)
- [Stalwart API Reference](https://stalw.art/docs/api/management/overview)
- [ImapFlow Documentation](https://imapflow.com/)
- [Nodemailer Documentation](https://nodemailer.com/)
