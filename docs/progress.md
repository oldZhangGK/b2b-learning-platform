# Progress Log

**Read this file first at the start of every session, then follow the Next Step.**

---

## Sprint 0.1 — Scope Review and Environment Check
**Date:** 2026-11-10
**Goal:** Initialize the repository, verify the development environment, and produce the scope/ADR draft.

### Completed
- `git init`, default branch renamed to `main`
- `.gitignore` added
- `README.md` created (prerequisites, layout, profiles, demo accounts, sprint table)
- `docs/progress.md` created (this file)
- `docs/adr/ADR-000-initial-scope.md` created (7 decisions, 5 open questions)
- Directory scaffolding: `docs/adr/`, `docs/runbooks/`, `docs/benchmarks/`

### Environment Check

```
Java:           17.0.19 (OpenJDK / Homebrew)  ⚠ JAVA 21 REQUIRED — blocks Sprint 1
Maven:          3.9.16  ✅
Node.js:        26.3.0  ✅
npm:            11.16.0 ✅
Docker:         29.4.2  ✅
Docker Compose: v5.1.3  ✅
```

**Blocking issue:** Java 21 is required (Spring Boot 3.2+ virtual threads). The machine has Java 17.

Upgrade:
```bash
brew install openjdk@21
echo 'export JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home' >> ~/.zshrc
source ~/.zshrc
java -version   # expect 21.x.x
mvn -version    # expect Java version: 21
```

### Unresolved Issues
- Java 21 not yet installed — blocks all service scaffolding in Sprint 1

### Next Step
**Sprint 0.2** — Confirm Java 21, then write the permission matrix and video-asset state machine.

Questions Sprint 0.2 will address:
1. Verify `java -version` reports 21 and `mvn -version` picks it up.
2. Write `docs/adr/ADR-001-service-boundaries.md` — why two services (identity + learning), not more.
3. Write the explicit permission matrix (ADMIN / INSTRUCTOR / STUDENT × every resource) as a Markdown table.
4. Write the video-asset state machine (PENDING_UPLOAD → QUEUED → PROCESSING → READY / FAILED / RETRY_PENDING) with valid transitions and DLQ reconciliation path.
5. Confirm Spring Boot 3.3.x + Spring Cloud 2023.x BOM is compatible with Java 21; pin versions in a note.

---

## Entry Template

```markdown
## Sprint N.M — <Goal>
**Date:** YYYY-MM-DD
**Goal:** one sentence

### Completed
- file / command / result

### Commands Run
```shell
command and actual output
```

### Acceptance Check
- [ ] criterion

### Unresolved Issues
- issue

### Next Step
single next task
```
