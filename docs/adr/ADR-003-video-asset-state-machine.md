# ADR-003: Video Asset State Machine

**Date:** 2026-11-10
**Status:** Accepted

---

## Context

Video processing is asynchronous and involves multiple failure modes: network errors, invalid media, worker crashes, duplicate SQS messages, and stale revisions. We need an explicit state machine with valid transitions, so that the system can recover predictably and the UI always reflects a meaningful status.

---

## States

| State | Meaning |
|-------|---------|
| `PENDING_UPLOAD` | Asset record created; instructor has the presigned S3 PUT URL but has not uploaded yet |
| `QUEUED` | S3 ObjectCreated received; Lambda validated and enqueued the event in SQS |
| `PROCESSING` | Worker has claimed the job and FFmpeg is running |
| `READY` | Transcoding complete; outputs written to S3; asset is playable |
| `RETRY_PENDING` | Transient failure; job will be retried by SQS visibility timeout expiry |
| `FAILED` | Permanent failure — invalid media, or retry exhaustion reached DLQ |

---

## Valid Transitions

```
PENDING_UPLOAD
    │
    │  S3 ObjectCreated → Lambda validates key → SQS enqueue
    ▼
QUEUED
    │
    │  Worker calls POST /internal/media-jobs/claim (atomic UPDATE WHERE status=QUEUED)
    ▼
PROCESSING ──────────────────────────────────────────────────────────┐
    │                                                                 │
    │  FFmpeg succeeds                     Transient failure         │  Permanent failure
    │  Worker POSTs /complete              (network, timeout)        │  (invalid media,
    ▼                                           │                    │   ffprobe rejection)
READY (terminal)                           RETRY_PENDING             │
                                                │                    ▼
                                                │  SQS redelivers   FAILED (terminal)
                                                │  after visibility     ▲
                                                │  timeout expiry       │
                                                ▼                       │
                                           PROCESSING              DLQ reconciliation
                                           (re-claimed)            task marks FAILED
                                                │                  if job stuck in
                                                │  Max attempts    PROCESSING after
                                                │  exhausted →     lease expiry
                                                ▼
                                              DLQ
                                                │
                                                │  Reconciliation task
                                                ▼
                                           FAILED (terminal)
```

---

## Transition Rules

### PENDING_UPLOAD → QUEUED
- Triggered by: S3 ObjectCreated event reaching Lambda
- Lambda validates: key matches the server-controlled pattern (`assets/{assetId}/{revision}/source`), bucket is the designated source bucket, versionId is present
- Lambda sends SQS message: `{schemaVersion, eventId, bucket, key, versionId, assetId, revision, occurredAt, traceId}`
- Learning-service updates status to QUEUED on receipt of a valid claim

### QUEUED → PROCESSING
- Worker calls `POST /internal/media-jobs/claim` with `{assetId, revision, sourceVersion}`
- Learning-service executes: `UPDATE video_assets SET processing_status='PROCESSING', lease_token=UUID(), lease_expires_at=NOW()+interval WHERE processing_status='QUEUED' AND asset_id=? AND revision=? AND source_version=?`
- If 0 rows updated: job already claimed or state changed — worker discards the message (safe duplicate handling)
- Lease duration: 10 minutes (must exceed maximum expected transcode time for the size limit)

### PROCESSING → READY
- Worker calls `POST /internal/media-jobs/{jobId}/complete` with output manifest (S3 keys, durations, sizes)
- Learning-service: within a single transaction, sets `processing_status='READY'`, writes `outputs_json`, verifies `lease_token` matches
- Worker then deletes the SQS message
- If lease_token mismatch: another worker completed this job first; current worker discards — outputs under deterministic keys make this idempotent

### PROCESSING → RETRY_PENDING (transient failure)
- Worker calls `POST /internal/media-jobs/{jobId}/fail` with `{leaseToken, errorCode, retryable: true}`
- Learning-service sets `processing_status='RETRY_PENDING'`
- Worker does NOT delete the SQS message; visibility timeout expires and SQS redelivers

### PROCESSING → FAILED (permanent failure)
- Worker calls `POST /internal/media-jobs/{jobId}/fail` with `{leaseToken, errorCode, retryable: false}`
- Learning-service sets `processing_status='FAILED'`
- Worker deletes the SQS message
- Triggered by: ffprobe rejects media as not a valid video, duration exceeds limit, file size exceeds limit after download

### RETRY_PENDING → PROCESSING
- SQS redelivers the original message after visibility timeout
- Worker claims the job via the same QUEUED→PROCESSING path; the status must be QUEUED or RETRY_PENDING at claim time
- `UPDATE … WHERE processing_status IN ('QUEUED','RETRY_PENDING')`

### DLQ delivery → FAILED
- After `maxReceiveCount` (configurable, default 3) delivery attempts, SQS moves the message to the DLQ
- A scheduled reconciliation task (runs every 5 minutes) scans `media_jobs` for rows in PROCESSING with an expired lease and no recent heartbeat, then sets them to FAILED
- This prevents a permanently PROCESSING state in the UI after a worker crash

---

## Idempotency Rules

| Scenario | Handling |
|----------|---------|
| Duplicate SQS message for same asset/revision | Claim UPDATE finds 0 rows (already PROCESSING/READY/FAILED); worker discards |
| Worker crashes after writing S3 outputs but before calling /complete | Re-claimed worker writes to same deterministic output keys (idempotent); calls /complete again |
| /complete called twice | Second call: lease_token no longer matches (first call cleared it); second call is a no-op |
| Stale revision event arrives after a newer revision is READY | Claim WHERE source_version=? finds 0 rows; worker discards |
| /fail called after lease expired and another worker completed | lease_token mismatch; /fail returns 409; worker discards |

---

## UI States

| `processing_status` | UI label |
|--------------------|----------|
| PENDING_UPLOAD | Waiting for upload |
| QUEUED | Queued for processing |
| PROCESSING | Processing… |
| READY | Ready |
| RETRY_PENDING | Processing (retrying…) |
| FAILED | Failed |

Vue polls `GET /api/videos/{id}/assets/{assetId}/status` every 5 seconds while status is not READY or FAILED.

---

## Consequences

- Deterministic S3 output keys under `assets/{assetId}/{revision}/` are required for idempotent re-processing.
- The lease mechanism requires a background reconciliation task from Sprint 5 onwards.
- Partial failed outputs (written to S3 before a crash) must never be served as playable content. Learning-service only marks READY after a successful /complete call; the outputs_json is not trusted from S3 object existence alone.
- The DLQ must have a CloudWatch alarm on `ApproximateNumberOfMessagesVisible > 0` to alert on stuck jobs.
