# B2B Learning Platform

A B2B educational video platform for institutional clients. Administrators import instructor, student, course, and enrollment data via CSV. Instructors manage assigned courses and rosters. Students access only enrolled courses and their videos.

Built with Java/Spring Boot microservices, Vue 3, MySQL, Elasticsearch, and an AWS Lambda/SQS/FFmpeg media pipeline.

## Prerequisites

| Tool | Required | Installed | Notes |
|------|----------|-----------|-------|
| Java | 21 | 17.0.19 | **Action required** — see upgrade instructions below |
| Maven | 3.9+ | 3.9.16 | ✅ |
| Node.js | 20+ | 26.3.0 | ✅ |
| Docker | 24+ | 29.4.2 | ✅ |
| Docker Compose | v2+ | v5.1.3 | ✅ |

**Java 21 upgrade (required before Sprint 1):**
```bash
brew install openjdk@21
echo 'export JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home' >> ~/.zshrc
source ~/.zshrc
java -version   # expect: openjdk 21.x.x
mvn -version    # expect: Java version: 21
```

## Repository Layout

```
apps/web/                   Vue 3 + TypeScript + Vite frontend
services/discovery-server/  Eureka service registry
services/identity-service/  Accounts, roles, JWT, account imports
services/learning-service/  Courses, enrollments, videos, search authorization
workers/media-worker/       SQS consumer, FFmpeg transcoding, status reporting
functions/upload-router/    Python Lambda: S3 ObjectCreated → SQS routing
contracts/                  OpenAPI specs and SQS event schemas
infra/local/                Docker Compose, DB init scripts, local adapters
infra/aws/                  IAM, S3, Lambda, SQS, CloudWatch definitions
infra/nginx/                Reverse proxy and TLS configuration
infra/jenkins/              Jenkinsfile and deployment scripts
scripts/                    Synthetic data generator, smoke tests, benchmarks
docs/adr/                   Architecture Decision Records
docs/runbooks/              Operational playbooks (uploads, DLQ, ES rebuild)
docs/benchmarks/            Query measurements and EXPLAIN output
docs/progress.md            Step-by-step engineering log — read this first
docs/requirements-evidence.md  Requirement → file → test → result traceability
```

## Runtime Profiles

Start services incrementally. Do not start every component on day one.

| Profile | Services |
|---------|----------|
| `core` | MySQL · Eureka · identity-service · learning-service · Vue · Nginx |
| `search` | core + Elasticsearch |
| `media-local` | search + media-worker + local S3/queue (MinIO + ElasticMQ) |
| `aws` | real AWS S3 · Lambda · SQS · CloudWatch |

## Quick Start — core profile (not yet implemented)

```bash
# Infrastructure
docker compose -f infra/local/docker-compose.yml --profile core up -d

# Backend services (separate terminals)
cd services/identity-service  && ./mvnw spring-boot:run
cd services/learning-service  && ./mvnw spring-boot:run

# Frontend
cd apps/web && npm install && npm run dev
```

## Demonstration Accounts (synthetic, local only)

Passwords are set by `scripts/seed-demo.sh`. Never commit credentials.

| Role | Email |
|------|-------|
| Admin | admin@demo.local |
| Instructor A | instructor-a@demo.local |
| Instructor B | instructor-b@demo.local |
| Student A | student-a@demo.local |
| Student B | student-b@demo.local |

Instructor A is assigned to Course 1; Instructor B to Course 2.  
Student A is enrolled in Course 1; Student B in Course 2.

## Running Tests

```bash
# Backend (requires Docker for Testcontainers)
cd services/identity-service  && ./mvnw test
cd services/learning-service  && ./mvnw test

# Frontend
cd apps/web && npm run test
```

## Sprint Status

| Sprint | Goal | Status |
|--------|------|--------|
| 0 | Scope, ADRs, environment | 🟡 In Progress |
| 1 | Repo scaffold, MySQL, Eureka, services | Planned |
| 2 | Login, courses, enrollments, authorization | Planned |
| 3 | CSV imports and roster UI | Planned |
| 4 | Query optimization | Planned |
| 5 | Local video workflow | Planned |
| 6 | Search and async indexing | Planned |
| 7 | AWS event workflow | Planned |
| 8 | EC2/Jenkins, handover | Planned |

## Cleanup

```bash
docker compose -f infra/local/docker-compose.yml down -v
```

Removes all local containers and volumes. No paid AWS resources are created until Sprint 7.
