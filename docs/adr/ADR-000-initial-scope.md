# ADR-000: Initial Scope and Architecture Assumptions

**Date:** 2026-11-10
**Status:** Accepted

---

## Context

Records the assumptions and constraints that govern the first version of the B2B Learning Platform. Derived from `project_plan.md` and the Sprint 0.1 environment check. Future ADRs refine individual decisions; this one establishes what is in scope and what is deferred.

---

## Decisions

### D1: Java 21 is the target JVM

**Rationale:** Spring Boot 3.2+ enables virtual threads (`spring.threads.virtual.enabled=true`) on Java 21, reducing thread-per-request overhead without async plumbing. Java 21 is also the LTS release with long-term Homebrew/Docker support.

**Current state:** Machine has Java 17.0.19. Must be upgraded before Sprint 1 service scaffolding.

**Consequence if skipped:** virtual threads unavailable; some Spring Boot 3.3+ features may not activate.

---

### D2: Two backend microservices only — identity-service and learning-service

**Rationale:** A service-per-table split increases operational overhead (N Eureka registrations, N Flyway histories, N Docker images) with no benefit at this scale. All cross-service transactions are avoided by design (staged CSV imports; no distributed XA). Two services keep dependency direction clear and testable.

**media-worker** and **upload-router** are separate deployment units (a Java worker and a Python Lambda) but are not Spring microservices and do not register with Eureka.

**Not in scope:** API Gateway, service mesh, Kubernetes. Nginx is the unified external entry point.

---

### D3: MySQL is the authorization authority; JWT carries identity only

**Rationale:** Embedding enrollments or assignments in a JWT creates a window where a revoked enrollment still grants access until token expiry. The spec explicitly prohibits this.

**Implementation rule:** Every enrollment-sensitive endpoint queries MySQL. JWTs are verified locally (RSA public key) on each request; no identity-service call per request. Revocation takes effect on the next API call. Already-issued presigned playback URLs remain valid for their TTL — this is a documented limitation, not a silent gap.

---

### D4: Nginx is the sole external entry point; no Spring Cloud Gateway

**Rationale:** Gateway adds latency, a new failure mode, and a service to maintain. Nginx handles TLS termination, rate limiting, and routing to identity/learning. Internal service-to-service calls (learning → identity bulk account lookup) use Eureka-resolved addresses directly with configured timeouts.

---

### D5: core profile only for Sprints 1–4; search/media/aws added incrementally

**Profile activation order:** core → search → media-local → aws. Each is additive; the application starts without non-core services and returns explicit "unavailable" responses for those features.

**Rationale:** Elasticsearch, FFmpeg, and AWS each add setup and cost. Keeping core minimal lets authorization, imports, and query optimization be verified in isolation.

---

### D6: Single MySQL instance for local dev; identity and learning use separate schemas and DB users

**Rationale:** Shared hardware for local development; isolated schemas prevent accidental cross-service joins. Each service owns its Flyway migration history. No cross-schema foreign keys are permitted.

---

### D7: Synthetic data with fixed seed; no real personal data in the repository

**Rationale:** Privacy obligations. The `scripts/` directory generates realistic but entirely fake instructors, students, courses, and enrollments. The seed is committed; counts are configurable. Generic email patterns are used for all demonstration accounts (`instructor-a@demo.local`, etc.); no real names appear anywhere in the codebase, documentation, or sample data.

**Default dataset:** 100 instructors, 3,000 students, configurable course/enrollment counts. Correctness is validated on small data before scaling up.

---

## Explicit Exclusions (core version)

| Excluded | Note |
|----------|------|
| React | Vue 3 only |
| RocketMQ, Kafka | SQS for media pipeline only |
| FastDFS, Redis bullet comments | Out of scope |
| Recommendation algorithms | Out of scope |
| Kubernetes / EKS, Azure, TimescaleDB | Future extensions |
| Public registration, payments, marketing, live streaming | Out of scope |
| Full examination system, certificates | Out of scope |
| Multi-tenant isolation | Single client assumed |
| CloudFront signed cookies | Optional extension; playback ADR will decide |

---

## Open Questions for Sprint 0.2

1. **Java 21 installed?** — gate for Sprint 1 service work
2. **Spring Boot version:** 3.3.x with Spring Cloud 2023.x BOM — confirm compatibility with Java 21
3. **Permission matrix:** explicit table of ADMIN / INSTRUCTOR / STUDENT × every resource and operation
4. **Video asset state machine:** transitions, terminal states, DLQ reconciliation path
5. **Cross-service account deactivation:** what happens to learning-service enrollments when identity-service deactivates an account? ADR needed.
