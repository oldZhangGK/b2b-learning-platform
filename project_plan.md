# B2B Learning Platform - Project Development Guide

## 1. Mission and working style

You are a Senior Software Engineer helping design and build a new B2B educational video platform from the ground up. Develop the product step by step, explaining business requirements, implementation decisions, and engineering practices.

Use English exclusively throughout the project: explanations, code identifiers, comments, API names and messages, UI text, sample data, tests, logs, commits, and documentation. Keep project content free of personal names and identifying details; use generic synthetic identities for demonstration accounts. Implement only one small, verifiable step at a time. Explain the rationale, affected files, execution commands, and acceptance checks. Do not generate the entire project at once or provide architecture advice without implementing the current step.

This is a new, independently developed project. Use synthetic data for development and testing. Treat the requirements and architecture below as the initial product specification, and record changes through architecture decision records.

### Working rules

1. Inspect the current directory and existing code first. Read the README, build configuration, migrations, and progress notes. Preserve existing work.
2. State the current step's goal and acceptance criteria before changing a small set of necessary files. Explain key business code in this order: Controller -> DTO -> Service -> Repository -> SQL/Domain.
3. Complete the current small step, run relevant checks, then stop and wait for the user to request the next step. Resolve routine implementation choices using the defaults in this document and record them rather than repeatedly asking questions.
4. Do not automatically expand the current step merely because the full Sprint remains unfinished. Distinguish implemented features from plans.
5. Keep business logic in services. Controllers must not access repositories directly. Avoid generic CRUD base classes or elaborate abstractions merely to reduce file count.
6. Prioritize tests for real risks: authorization boundaries, transactions, imports, and message retries. Fully mocked dependencies do not constitute a MySQL integration test.
7. Never fabricate test results, performance measurements, successful cloud deployments, or delivered capabilities. If execution is blocked, explain why and provide reproducible commands.
8. Update `docs/progress.md` after every step: completed work, actual commands and results, unresolved issues, and the next small step. Record significant decisions as ADRs.
9. AWS and Jenkins configuration may be prepared, but do not create paid resources, publish publicly, or push to a remote repository without explicit instruction. Never commit secrets.
10. Use synthetic users, demonstration accounts, and self-created or appropriately licensed sample videos. Keep private data and credentials out of the repository.

## 2. Product requirements and scope

This document defines the initial requirements for the new platform. Keep implementation, API contracts, tests, and documentation aligned with these requirements. Record approved scope changes in ADRs and progress notes.

### Core product capabilities

| Product requirement | Acceptance evidence |
| --- | --- |
| Java/Spring Boot microservices, validation, centralized exceptions, pagination, Eureka | Working service registration, APIs, error model, and pagination tests |
| Target dataset of approximately 3,000 students and 100 instructors | Configurable synthetic dataset generator; user count is not concurrency |
| Enrollment-based student access and instructor management of assigned courses | Database-backed authorization for queries and resource endpoints, with negative tests |
| MySQL imports for instructors, students, courses, and enrollments | Validation, deduplication, reference checks, reports, and repeated-import tests |
| Replacing repeated per-course queries with batched queries | Equivalent baseline and optimized results, with database round-trip comparisons |
| S3-triggered Lambda/SQS workflow, transcoding, thumbnails, multiple resolutions | Actual FFmpeg processing, event flow, retries, idempotency, DLQ, and status updates |
| Elasticsearch search combined with relational authorization | Separation of index metadata and MySQL permissions; immediate access-denial tests after enrollment revocation |
| Docker, EC2, Nginx, Jenkins, CloudWatch | Dockerfiles, deployment scripts, pipeline, logs, and troubleshooting runbooks |
| Vue.js course management, rosters, uploads, and processing status | Usable pages, API integration, and error feedback |
| JUnit integration tests and Claude Code-assisted development | Executable tests and documented human review of generated changes |

### Business context

The target customer is an educational institution with existing instructor, student, course, and enrollment data. Internal administrators import that data. On login, instructors see their assigned courses and student rosters without manually entering student IDs to establish every relationship. Students see only authorized courses and the available videos within them.

### Explicit exclusions from the core version

Keep the initial technical scope focused. React, RocketMQ, Kafka, FastDFS, Redis-based bullet comments, recommendation algorithms, Kubernetes/EKS, Azure, and TimescaleDB are outside the core version. Consider them only as separately scoped future extensions after the core workflow is complete.

Do not implement payments, public registration, marketing, live streaming, a full examination system, or certificates. Assume one client institution. Multi-tenant isolation is not an implemented capability of this version.

Establish performance baselines through actual measurements. Document the environment and workload for every conclusion; do not infer concurrency capacity from user counts or invent improvement percentages.

## 3. Target stack and deployment profiles

Use the following initial technology choices:

- Java 21, Maven Wrapper, Spring Boot, and a compatible Spring Cloud BOM / Netflix Eureka release.
- Spring MVC, Spring Security, Bean Validation, Spring Data JPA, Flyway.
- MySQL 8, Elasticsearch, Vue 3 + TypeScript + Vite + Vue Router.
- JUnit 5, Mockito, Testcontainers MySQL; Vitest and a small set of frontend end-to-end checks.
- AWS SDK for Java v2, a Python Lambda event router, and a Java media worker with FFmpeg.
- Docker Compose locally; an EC2 Docker Compose + Nginx demonstration deployment; Jenkins builds/deployments; CloudWatch logs and alarms.

Before adding dependencies, check official compatibility matrices. Pin concrete versions, container tags, and the frontend lockfile. Do not casually use `latest`. Verify versions when needed for the current step rather than researching every dependency upfront.

### Incremental runtime profiles

- `core`: MySQL, Eureka, identity-service, learning-service, Vue, and Nginx.
- `search`: add Elasticsearch. The application must still start without search; search endpoints return an explicit unavailable response.
- `media-local`: add the worker, local object storage, and queue adapters; run real FFmpeg. S3-compatible storage and a local queue emulator are acceptable if their limitations are documented.
- `aws`: real S3 -> Lambda -> SQS -> EC2 worker, including real events and IAM verification. Local emulation alone does not satisfy AWS acceptance.

Start with `core`; do not start every middleware component on day one. Check development-machine resources and document startup commands for each profile.

## 4. Service boundaries and repository

Use a small number of understandable microservices. Do not create a service for every table.

```text
apps/web/                         Vue frontend
services/discovery-server/        Eureka
services/identity-service/        Accounts, passwords, roles, JWT, account imports
services/learning-service/        Courses, assignments, enrollments, imports, video metadata, search authorization
workers/media-worker/             SQS consumption, FFmpeg, output upload, status reporting
functions/upload-router/          Python Lambda routing S3 events to SQS
contracts/                       OpenAPI and JSON event schemas
infra/local/                     Compose, initialization, local adapter configuration
infra/aws/                       Cloud resource definitions, IAM, deployment, cleanup
infra/nginx/                     Routing and proxy configuration
infra/jenkins/                   Jenkinsfile and deployment scripts
scripts/                         Synthetic data, smoke tests, measurement scripts
docs/adr/                        Architecture decisions
docs/runbooks/                   Troubleshooting, retries, replay, rollback
docs/progress.md                  Progress entry point for the next session
docs/requirements-evidence.md     Implementation and verification mapped to product requirements
```

Organize Java services by feature, for example `course/{api,application,domain,infrastructure}`. Smaller features may use a simpler structure, while keeping dependency direction clear.

Identity and learning each own their schema, database user, and Flyway migrations. They may share one local MySQL instance. No direct cross-service table queries or cross-service foreign keys. Keep course, assignment, enrollment, and video data within learning-service transactions for consistent authorization.

Use Nginx as the unified entry point; do not add Spring Cloud Gateway. Use Eureka for registration and controlled internal calls. Service discovery must actually be exercised, not just run as an unused registry. During imports, learning may discover identity's account-mapping API through Eureka. Validate normal user JWTs locally using a public key rather than calling identity on every request.

## 5. Domain and invariants

### Identity schema

- `users(id UUID, external_id unique, email unique, display_name, password_hash, active, created_at)`.
- `roles` and `user_roles`: ADMIN, INSTRUCTOR, STUDENT; an account may have multiple roles.
- Define and test normalization rules for email and external IDs to prevent case-related duplicate accounts.

### Learning schema

- `courses(id, external_id unique, title, description, status, version)`.
- `instructor_assignments(course_id, instructor_user_id, active)` with a composite uniqueness constraint.
- `enrollments(course_id, student_user_id, status, enrolled_at)` with a composite uniqueness constraint.
- `videos(id UUID, course_id, title, description, publication_status, current_revision)`.
- `video_assets(id UUID, video_id, revision, source_key, source_version, processing_status, outputs_json, error_code, updated_at)`.
- `import_batches`, `import_rows`: batches, idempotency keys, per-row outcomes, and associated entities.
- `index_outbox`: search-index synchronization events, entity versions, and retry state.
- `media_jobs`: job ID, asset ID, source version, status, lease, attempt, and output manifest.

### Authorization rules

1. ADMIN manages global data and imports. INSTRUCTOR manages only currently assigned courses, rosters, and videos.
2. STUDENT accesses only courses with an ACTIVE enrollment. Playback additionally requires a published course, published video, and READY playable asset.
3. JWT establishes identity and roles only. MySQL remains authoritative for enrollments and assignments. Do not embed them in long-lived JWTs and stop checking the database.
4. Apply resource-level authorization to lists, details, search, upload, processing status, and playback URLs. Hiding frontend controls is not authorization.
5. Deny by default. Test attempts using another course ID, video ID, or user ID. Avoid leaking sensitive information through missing-versus-forbidden resource responses.
6. After enrollment revocation, immediately deny subsequent API access and playback-URL issuance. Already issued presigned URLs may remain valid for their short TTL; document this limitation rather than claiming immediate revocation of every byte of access.
7. Store external user UUIDs without cross-service database foreign keys. Document cross-service account-deactivation behavior in an ADR, including short-lived token limitations.

## 6. Required business workflows

### 6.1 Login and course access

Administrators create or reset demonstration accounts. There is no public registration. Hash passwords with a supported algorithm such as BCrypt or Argon2. Short-lived JWTs contain subject, roles, issuer, audience, and expiry; services verify signatures and claims. Keep keys outside the repository.

Begin with a minimal dataset: administrator, instructors A/B, and students A/B. Instructors access assigned courses and rosters; students access enrolled courses and videos. Use a consistent error format: `code,message,fieldErrors,traceId`, without stack traces. Use stable pagination ordering and enforce a maximum page size.

### 6.2 Relational imports

Use CSV in this sequence: accounts -> courses -> instructor assignments -> enrollments. Document fields and sample files. Imported references use external IDs, which the backend maps to internal IDs.

- Use staged imports for the MVP. Do not promise distributed atomic transactions across identity and learning.
- Identity imports accounts. Learning validates references and roles through a protected bulk account lookup API.
- Validate before writing. Return file-level and row-level errors. Limit file size and row count.
- Default to rejecting the entire file without business-data writes if any row fails validation. On success, write within a same-service transaction. Avoid long-running cross-service transactions.
- Identical external/composite keys and values are `unchanged`. Explicitly allowlist updatable fields; report conflicts.
- Reports include at least total, created, updated, unchanged, failed, row numbers, and failure reasons.
- Support dry-run. Repeating a batch key must not repeat execution; reject the same key with different content.
- Imports must not implicitly revoke enrollments absent from the file. Revocation is an explicit operation.
- Do not pretend real email delivery exists during account initialization. Supply local passwords through a safe demonstration mechanism, not public reports.

### 6.3 Query optimization

Keep an understandable per-course-query baseline in an isolated benchmark/test fixture. Then implement paginated ID queries plus batched enrollment, assignment, and metadata queries. Do not expose the baseline as an optional production vulnerability path.

Prove identical results for identical input and permissions, and demonstrate that adding courses does not add one SQL query per course. A fixed number of multiple queries is acceptable; a single SQL statement is not required. Avoid collection fetch joins that cause in-memory pagination or duplicate results.

Measure SQL statement counts, result counts, repeated-run latency, dataset size, indexes, machine environment, and cold/warm conditions for 10/50/100-course scenarios. Use Hibernate statistics or datasource instrumentation and verify SELECT counts. Include EXPLAIN output. Do not prepopulate improvement percentages.

### 6.4 Video upload and asynchronous processing

Architecture decision: Lambda routes upload events. An SQS consumer in an EC2 worker container runs FFmpeg for long-running video transcoding. This separates lightweight event routing from resource-intensive media processing.

Workflow:

1. An authorized instructor requests an upload session. Learning creates a video asset and generates a server-controlled random source key and short-lived S3 PUT URL.
2. The browser uploads directly to a private source bucket. Use separate source and output buckets to prevent output objects from retriggering input processing.
3. Source-bucket ObjectCreated -> Lambda. Parse and validate the key, bucket, and version information, then send a versioned event to SQS.
4. The worker atomically claims the job through an authenticated internal learning API. Verify the asset is bound to that object and check S3 metadata and size limits.
5. Download into a temporary directory. Use ffprobe to validate actual media, duration, and limits. Generate thumbnails and 360p/720p HLS with FFmpeg; do not upscale small sources unnecessarily. Produce suitable renditions.
6. Write outputs under the asset/revision prefix in the private output bucket. Submit the output manifest; learning transactionally marks the asset READY.
7. Acknowledge/delete the message only after the result is durably persisted. Retry failures according to policy; exhausted retries reach the SQS DLQ. Provide controlled replay tooling and an operation record.
8. Vue polls processing status and displays uploading, queued, processing, successful, and failed states. Upload completion does not mean the video is immediately playable.

Events include at least `schemaVersion,eventId,bucket,key,versionId,assetId,revision,occurredAt,traceId`. Enable source-bucket versioning. Do not treat ETag as a reliable content MD5. Lambda derives asset/revision from the server-controlled key convention; the worker verifies it against the database. Do not trust arbitrary client-supplied object locations.

### Idempotency and failure recovery

- S3/SQS events may be duplicated or reordered. Do not claim exactly-once processing. Deduplicate by asset ID + revision + source version, enforced by database uniqueness.
- Claim jobs with an atomic state update and expiring lease. Verify the lease token when committing completion. An in-process Set is insufficient.
- Extend SQS visibility timeout for long tasks. After a crash, expired leases allow another worker to claim the job.
- Use deterministic output keys. Repeated processing must not create duplicate assets. Partial failed outputs must never become playable content.
- Success/failure events for an old revision must not overwrite a newer revision. Safely retry when output upload succeeds but database status reporting fails.
- Keep transient failures retryable. Mark permanently invalid media as failed and stop repeated transcoding. Distinguish invalid input from infrastructure failure.
- After retry exhaustion and DLQ delivery, use a reconciliation task to mark the corresponding job failed, preventing a permanently PROCESSING UI.
- States: PENDING_UPLOAD -> QUEUED -> PROCESSING -> READY; errors enter RETRY_PENDING/FAILED. Allow controlled completion transitions when stored state lags, and test events arriving before UI confirmation.

### Playback security

Keep S3 buckets private. Before issuing short-lived playback authorization, verify enrollment and course/video publication in MySQL. HLS contains playlists and multiple segments; signing only a playlist URL does not automatically authorize its child resources.

For the local MVP, a protected proxy may serve HLS child resources. An AWS implementation may sign all child resources referenced by the playlist or use CloudFront signed cookies. CloudFront is an optional extension; document the selected playback-delivery approach in an ADR. Document TTL, path scope, and revocation limitations.

### 6.5 Search with authoritative authorization

- Elasticsearch stores course/video search metadata and entity versions. It is not the enrollment authority and must not contain secrets.
- Learning transactionally writes business changes and index_outbox records. A poller asynchronously updates the index, supporting retries, deletion, and rebuilds. Use version control to prevent stale events from overwriting newer documents.
- Determine the student's currently authorized courses, then filter ES by those course IDs and publication conditions. Filter instructor searches by assignments and administrator searches by management scope.
- Recheck hits in a batch against MySQL for current authorization, entity existence, and publication. Avoid per-result permission queries.
- Enrollment revocation must not depend on index updates. Revalidation must prevent disclosure of unauthorized course titles or video content.
- If stale index hits are removed, fetch more candidates with bounded search_after iterations. Return cursor and hasMore; do not present raw ES total as the exact authorized result count.
- Use ordinary pagination for course lists and a separate cursor contract for search. Large-scale authorization-set optimization is future work.
- Return recognizable errors when search is unavailable; MySQL-backed course lists remain usable. Document eventual-consistency delays.

## 7. API and UI contracts

Build OpenAPI contracts incrementally. Do not generate every controller at once. Suggested entry points:

- Identity: `POST /api/auth/login`, `GET /api/auth/me`, administrator account imports.
- Learning: `GET /api/courses`, `GET /api/courses/{id}`, course creation/update/publication.
- Instructor: course rosters, video metadata, upload sessions, processing status.
- Student: course videos and playback authorization. Filter by authenticated identity; do not accept arbitrary client-selected student IDs.
- Administrator: course/assignment/enrollment imports, dry-run, reports, enrollment revocation.
- Search: `GET /api/search?q=...&cursor=...&limit=...`.
- `/internal/...`: bulk account mapping and job claim/heartbeat/complete/fail. Require service identities; do not expose through public Nginx routes.

Validate field lengths and state transitions on write endpoints. Set service-call timeouts and avoid infinite retries. Specify and test consistent 401/403/404/409/422 semantics.

Vue pages: login, student courses and playback, instructor courses and rosters, upload and processing status, administrator import reports, and authorized search. Include loading/empty/error/retry states and consistent pagination/filter behavior. Keep the UI practical and prioritize the complete functional workflow.

## 8. Security, operations and delivery

- Store browser tokens in memory by default; refreshing requires another login. If HttpOnly cookies are introduced, define CSRF protection. Do not claim JWT automatically solves CSRF.
- Define a CORS allowlist. Do not render untrusted content through v-html. Never log passwords, JWTs, presigned URLs, or sensitive personal fields.
- Configure Nginx HTTPS, request limits, and timeouts. Expose only necessary entry points. Keep Eureka, databases, ES, and internal APIs off the public internet.
- Apply least privilege: Lambda needs relevant logging and queue-send permissions; the worker reads sources, writes specified output prefixes, consumes the queue, and calls internal job APIs.
- Provide health/readiness checks, structured logs, and traceId propagation across upload, Lambda, SQS, worker, and status updates.
- CloudWatch coverage includes API 5xx, Lambda errors, SQS oldest-message age, DLQ messages, and processing failures. Include one demonstrated troubleshooting scenario.
- Jenkins: backend tests, frontend checks/build, image builds tagged with commit SHA, registry push, EC2 deployment, health/smoke checks, and rollback to the previous image.
- Do not claim production security through shortcuts such as a shared Docker socket. Explain Jenkins permissions and credential injection.
- Keep database migrations backward compatible. Rolling back an image does not roll back the database. A single EC2 instance is a demonstration deployment, not high availability.
- Document cleanup, log retention, object lifecycle, and costs. Mark unverified AWS steps as pending.

## 9. Sprint plan and acceptance

Split each Sprint into small steps. Advance only one step at a time.

| Sprint | Goal | Acceptance |
| --- | --- | --- |
| 0 | Business, domain, ADRs, environment checks | Explicit permission matrix, state machines, boundaries, version decisions; no bulk code generation |
| 1 | Repository, MySQL, identity, learning, Eureka | Services start/register; Flyway supports repeat startups; basic health checks |
| 2 | Login, courses, enrollments, assignments | Student A/B and instructor A/B authorization tests pass; stable course pagination |
| 3 | CSV imports and roster UI | Dry-run, duplicates, conflicts, unknown references, rollback tests pass |
| 4 | Query optimization and evidence | Equivalent results; SQL-count report for 10/50/100 courses; no invented improvements |
| 5 | Local video workflow | Real small-video transcoding, thumbnails, playback; duplicate/failure/crash recovery verified |
| 6 | Search and asynchronous indexing | Authorization, revocation, deletion, indexing-delay, and unavailability tests pass |
| 7 | AWS event workflow | Real S3/Lambda/SQS/worker/CloudWatch end-to-end verification; recoverable DLQ |
| 8 | EC2/Jenkins and handover | Deployment, smoke tests, rollback, complete demonstration, requirements verification index |

Tests must cover at least:

- Direct video/playback requests without enrollment are denied; search access and playback issuance are denied after enrollment revocation.
- Instructor A cannot modify instructor B's courses, rosters, or upload sessions.
- Reimporting the same CSV does not duplicate relationships; any invalid row triggers the specified file-level rollback.
- Testcontainers MySQL verifies real SQL, constraints, transactions, and REST-to-database integration.
- SQS duplicate messages, expired leases, process interruptions, stale revisions, failed completion reporting, and DLQ replay.
- Stale or incorrect ES documents cannot bypass MySQL authorization; unauthorized content appears in neither results nor visible totals.
- A browser demonstration completes administrator import -> instructor roster -> upload -> READY -> student search -> playback.

Use a fixed seed for synthetic data. Default to 3,000 students and 100 instructors, with configurable course/enrollment counts. Establish correctness on small data before generating larger datasets. Synthetic user counts are not real customer counts or load-test results.

## 10. Required documentation and evidence

- README: dependencies, staged startup, testing, access to demonstration accounts, troubleshooting, cleanup.
- ADRs: service boundaries, authorization authority, import transactions, transcoding location, idempotency, playback protection, search consistency.
- `docs/requirements-evidence.md`: each product requirement -> files/APIs -> tests/commands -> actual results -> limitations.
- `docs/benchmarks/`: datasets, query baseline, actual measurements, environment, raw output.
- `docs/runbooks/`: stuck uploads, Lambda failures, queue backlog, DLQ replay, ES rebuild, deployment rollback.
- `docs/engineering-notes.md`: business workflows, key code walkthroughs, design tradeoffs, failure recovery, and measured performance.

Track every requirement honestly using statuses such as planned / implemented / locally verified / AWS verified. Report only capabilities supported by implementation and verification evidence.

## 11. First response and first task

Read the current repository and summarize the files and environment you find. Then provide a scope review of no more than one page, identifying the initial product and architecture assumptions in this document.

For the first task, complete only Sprint 0.1: create or update README, `docs/progress.md`, and the initial scope/ADR draft. Do not generate all services, start paid resources, or implement all business code. Finish by explaining the files, acceptance results, and the single question Sprint 0.2 will address.

When the user says “continue,” first read `docs/progress.md` and follow its next small step. Do not restart the project.
