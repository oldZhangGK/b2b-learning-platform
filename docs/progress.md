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

## Sprint 0.2 — Permission Matrix, State Machine, Version Decisions
**Date:** 2026-11-10
**Goal:** Confirm Java 21, write service-boundary ADR, permission matrix, and video-asset state machine; pin Spring Boot/Cloud versions.

### Completed
- Java 21.0.13 confirmed (`java -version`, `mvn -version` both show 21) — Sprint 0.1 blocker resolved
- `docs/adr/ADR-001-service-boundaries.md` — why two services; media-worker and Lambda are not Spring services
- `docs/adr/ADR-002-authorization-authority.md` — MySQL as auth authority; full permission matrix across all resources and roles
- `docs/adr/ADR-003-video-asset-state-machine.md` — state diagram, valid transitions, idempotency rules, DLQ reconciliation

### Commands Run
```shell
java -version
# openjdk version "21.0.13.0.3" 2026-10-24

mvn -version
# Java version: 21.0.13.0.3
```

### Version Decisions (to be pinned in pom.xml at Sprint 1)
Verify against https://spring.io/projects/spring-cloud at Sprint 1 before writing any pom.xml.
Planned pins (subject to compatibility check):
- Spring Boot: 3.3.x (latest patch — check Maven Central at Sprint 1)
- Spring Cloud BOM: 2023.0.x (Leyton — compatible with Spring Boot 3.3.x)
- Eureka: via `spring-cloud-starter-netflix-eureka-server` / `spring-cloud-starter-netflix-eureka-client`
- Java source/target: 21
- Maven Wrapper: pin version at Sprint 1 (`mvn wrapper:wrapper -Dmaven=3.9.16`)

### Acceptance Check
- [x] `java -version` → 21.0.13
- [x] `mvn -version` → Java version 21
- [x] ADR-001 written (service boundaries)
- [x] ADR-002 written (permission matrix — all roles × all resources)
- [x] ADR-003 written (state machine — all states, transitions, idempotency)

### Unresolved Issues
- Spring Boot/Cloud exact patch versions not yet verified — deferred to Sprint 1 pom.xml creation

### Next Step
**Sprint 1.1** — Create the Maven multi-module root POM and the discovery-server (Eureka) module.

Sprint 1.1 will:
1. Verify Spring Boot 3.3.x + Spring Cloud 2023.0.x compatibility at the official matrix page
2. Create `pom.xml` (parent, multi-module: discovery-server, identity-service, learning-service)
3. Create `services/discovery-server/` with Spring Cloud Netflix Eureka Server
4. Run `./mvnw spring-boot:run` in discovery-server and confirm it starts and shows the Eureka dashboard at `http://localhost:8761`

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
