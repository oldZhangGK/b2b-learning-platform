# ADR-002: Authorization Authority and Permission Matrix

**Date:** 2026-11-10
**Status:** Accepted

---

## Context

The platform has three roles (ADMIN, INSTRUCTOR, STUDENT) and a range of resources spread across two services. We need a single, authoritative statement of who can do what, and which system enforces it at runtime.

---

## Decision

**MySQL is the authorization authority for all enrollment and assignment decisions. JWT is identity and roles only.**

Enrollments and instructor assignments are never embedded in JWTs. Every request that requires enrollment or assignment verification queries MySQL directly in the handling service. JWT signatures are verified locally using the RSA public key; identity-service is not called on each request.

---

## Rationale

A JWT-embedded enrollment would remain valid until token expiry after revocation — potentially minutes or hours. The spec requires that revocation takes effect on the next API call. Only a database query at request time satisfies this.

The tradeoff is one additional MySQL read on enrollment-sensitive paths. At this scale (hundreds of concurrent users, not millions) this is acceptable and measurable. Caching is deferred until benchmarks show a problem.

---

## Permission Matrix

The table below is the authoritative specification. Every controller method in identity-service and learning-service must map to one row. Tests must cover the ✗ cells (deny cases) as well as the ✓ cells.

### Identity-service resources

| Resource / Operation | ADMIN | INSTRUCTOR | STUDENT | Notes |
|----------------------|-------|------------|---------|-------|
| POST /api/auth/login | ✓ | ✓ | ✓ | Any active account |
| GET /api/auth/me | ✓ | ✓ | ✓ | Own account only |
| POST /internal/accounts/bulk-lookup | service | ✗ | ✗ | learning-service only; not exposed via Nginx |
| POST /api/admin/accounts/import | ✓ | ✗ | ✗ | CSV account import |
| POST /api/admin/accounts/import/dry-run | ✓ | ✗ | ✗ | |
| GET /api/admin/accounts/import/{batchId} | ✓ | ✗ | ✗ | Import report |
| POST /api/admin/accounts/{id}/deactivate | ✓ | ✗ | ✗ | |

### Learning-service — Course resources

| Resource / Operation | ADMIN | INSTRUCTOR | STUDENT | Notes |
|----------------------|-------|------------|---------|-------|
| GET /api/courses | ✓ all | ✓ assigned only | ✓ enrolled only | Filtered by role at the query level |
| GET /api/courses/{id} | ✓ | ✓ if assigned | ✓ if enrolled | 403 (not 404) for unauthorized |
| POST /api/courses | ✓ | ✗ | ✗ | |
| PUT /api/courses/{id} | ✓ | ✓ if assigned | ✗ | |
| POST /api/courses/{id}/publish | ✓ | ✓ if assigned | ✗ | |
| POST /api/courses/{id}/unpublish | ✓ | ✓ if assigned | ✗ | |

### Learning-service — Instructor assignment resources

| Resource / Operation | ADMIN | INSTRUCTOR | STUDENT | Notes |
|----------------------|-------|------------|---------|-------|
| GET /api/courses/{id}/instructors | ✓ | ✓ if assigned | ✗ | |
| POST /api/courses/{id}/instructors | ✓ | ✗ | ✗ | Assign instructor |
| DELETE /api/courses/{id}/instructors/{userId} | ✓ | ✗ | ✗ | Revoke assignment |

### Learning-service — Enrollment resources

| Resource / Operation | ADMIN | INSTRUCTOR | STUDENT | Notes |
|----------------------|-------|------------|---------|-------|
| GET /api/courses/{id}/enrollments | ✓ | ✓ if assigned | ✗ | Roster |
| POST /api/enrollments/import | ✓ | ✗ | ✗ | CSV enrollment import |
| POST /api/enrollments/import/dry-run | ✓ | ✗ | ✗ | |
| GET /api/enrollments/import/{batchId} | ✓ | ✗ | ✗ | |
| DELETE /api/courses/{id}/enrollments/{userId} | ✓ | ✗ | ✗ | Explicit revocation only |

### Learning-service — Video resources

| Resource / Operation | ADMIN | INSTRUCTOR | STUDENT | Notes |
|----------------------|-------|------------|---------|-------|
| GET /api/courses/{id}/videos | ✓ | ✓ if assigned | ✓ if enrolled | Student: published + READY assets only |
| GET /api/videos/{id} | ✓ | ✓ if assigned to course | ✓ if enrolled + published | |
| POST /api/courses/{id}/videos | ✓ | ✓ if assigned | ✗ | |
| PUT /api/videos/{id} | ✓ | ✓ if assigned to course | ✗ | |
| POST /api/videos/{id}/publish | ✓ | ✓ if assigned to course | ✗ | |
| POST /api/videos/{id}/upload-session | ✓ | ✓ if assigned to course | ✗ | Returns presigned S3 PUT URL |
| GET /api/videos/{id}/assets/{assetId}/status | ✓ | ✓ if assigned to course | ✗ | Processing status |
| POST /api/videos/{id}/playback | ✓ | ✓ if assigned to course | ✓ if enrolled + published + READY | Returns short-lived presigned GET URL |

### Learning-service — Internal (not exposed via Nginx)

| Resource / Operation | Caller | Notes |
|----------------------|--------|-------|
| POST /internal/media-jobs/claim | media-worker | Atomic job claim |
| POST /internal/media-jobs/{jobId}/heartbeat | media-worker | Extends SQS visibility timeout |
| POST /internal/media-jobs/{jobId}/complete | media-worker | Marks asset READY |
| POST /internal/media-jobs/{jobId}/fail | media-worker | Marks asset FAILED |

### Learning-service — Search

| Resource / Operation | ADMIN | INSTRUCTOR | STUDENT | Notes |
|----------------------|-------|------------|---------|-------|
| GET /api/search | ✓ all | ✓ assigned only | ✓ enrolled only | ES query filtered by MySQL-authorized course IDs; hits re-validated in MySQL |

---

## Deny-by-default rules

1. Any resource not listed above is denied to all roles.
2. A missing resource returns 404 only when the caller would have permission to know it exists (ADMIN always; INSTRUCTOR/STUDENT only within their authorized scope). Otherwise return 403.
3. After enrollment revocation, the next request to any enrollment-gated endpoint is denied. Already-issued presigned playback URLs remain valid for their TTL (documented limitation, not a bug to silently ignore).
4. Hiding UI controls is not authorization. Every deny case must be enforced at the API layer and tested with a direct HTTP call that bypasses the UI.

---

## Consequences

- Each enrollment-sensitive endpoint performs one MySQL lookup per request. This is intentional and measurable.
- Sprint 2 tests must include explicit negative cases: student A cannot see student B's enrollments; instructor A cannot modify instructor B's courses.
- The `/internal/` prefix on media-worker endpoints is enforced by Nginx: those paths are not proxied to external callers.
