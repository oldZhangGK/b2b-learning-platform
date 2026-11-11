# ADR-001: Service Boundaries

**Date:** 2026-11-10
**Status:** Accepted

---

## Context

The platform needs to serve three distinct authentication domains (admin, instructor, student), manage relational data across accounts and courses, and run a resource-intensive media pipeline. The question is how many Spring Boot microservices to create and where to draw the lines.

---

## Decision

**Two Spring Boot microservices: identity-service and learning-service.**

Two additional deployment units that are not Spring Boot services:
- **media-worker** — a Java process (not a web server) that consumes SQS messages and runs FFmpeg. Registered nowhere; communicates only with learning-service via an internal HTTP API and with S3/SQS directly.
- **upload-router** — a Python AWS Lambda. Triggered by S3 ObjectCreated events; routes to SQS. No persistent state.

---

## Rationale

### Why not one monolith?

Identity and learning have meaningfully different data lifecycles and security boundaries. Identity owns credentials and password hashing; learning owns enrollment state, which is the authorization authority for every content request. Separating them makes it possible to rotate JWT keys or change password policy without touching course logic, and vice versa.

### Why not more than two microservices?

The rejected alternatives:

| Alternative | Problem |
|-------------|---------|
| course-service + enrollment-service | Enrollment authorization requires a join with course publication status. Splitting them forces a cross-service call on every content request or duplicates data. |
| video-service separate from learning | Video authorization depends on enrollment, which lives in learning. A separate service would need to call learning on every playback request, adding latency and a failure mode. |
| search-service | Search results must be filtered by enrollment/assignment data from learning. A dedicated search service would either duplicate that data or call learning on every query. The outbox pattern keeps indexing in learning without blocking the request path. |

### Why is media-worker not a Spring Boot service?

Transcoding jobs are long-running (minutes), not HTTP requests (milliseconds). A web server model is the wrong abstraction. The worker is a plain Java application with a poll loop, not a Spring MVC service. It does not register with Eureka because nothing needs to discover it — it discovers work through SQS.

### Why no Spring Cloud Gateway?

Nginx handles TLS termination, rate limiting, and routing to the two services. Adding Gateway introduces a new latency hop, a new service to operate, and a new failure mode without providing anything Nginx does not already cover for this scale.

---

## Consequences

- Learning-service is the largest service and owns the most tables. Feature packages (`course/`, `enrollment/`, `video/`, `search/`, `import/`) keep it navigable without splitting into separate services.
- Cross-service communication is limited to one call: during CSV imports, learning calls identity's internal bulk account-lookup API (Eureka-discovered, authenticated, with a configured timeout). No other cross-service calls exist in steady-state operation.
- JWT verification is local in every service (RSA public key); no identity call per request.
- If learning-service grows too large in a future version, `enrollment` or `video` are the natural split candidates. That is deferred until there is evidence of a problem.

---

## Service Responsibilities Summary

| Service | Owns | Does not own |
|---------|------|--------------|
| identity-service | users, roles, user_roles, password hashes, JWT issuance, account imports | Courses, enrollments, videos |
| learning-service | courses, instructor_assignments, enrollments, videos, video_assets, media_jobs, import_batches, index_outbox | User credentials, JWT issuance |
| media-worker | FFmpeg execution, S3 output writes, job status reporting | No database tables — calls learning's internal API |
| upload-router (Lambda) | S3 event parsing, SQS message dispatch | No database tables |
