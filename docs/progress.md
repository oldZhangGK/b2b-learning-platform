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

## Sprint 1.1 — Root POM, Maven Wrapper, Eureka Discovery Server
**Date:** 2026-11-10
**Goal:** Create the multi-module root POM, generate the Maven wrapper, and start the Eureka discovery server.

### Completed
- `pom.xml` (root, multi-module parent): Spring Boot 3.3.4, Spring Cloud BOM 2023.0.3, Java 21
- `services/discovery-server/pom.xml`: eureka-server + actuator dependencies
- `services/discovery-server/src/main/java/com/b2b/learning/discovery/DiscoveryServerApplication.java`
- `services/discovery-server/src/main/resources/application.yml`: port 8761, standalone (no self-registration)
- Maven wrapper generated (`mvn wrapper:wrapper -Dmaven=3.9.16`)

### Commands Run
```shell
export JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home
./mvnw package -pl services/discovery-server    # BUILD SUCCESS
./mvnw spring-boot:run -pl services/discovery-server
curl http://localhost:8761/actuator/health      # {"status":"UP"}
```

Note: `JAVA_HOME` must be exported explicitly in a new terminal before running `./mvnw`. The `.zshrc` sets it on login; a new terminal session will have it automatically.

### Acceptance Check
- [x] `./mvnw package -pl services/discovery-server` → BUILD SUCCESS
- [x] `curl http://localhost:8761/actuator/health` → `{"status":"UP"}`
- [x] Eureka dashboard accessible at http://localhost:8761

### Unresolved Issues
- None

### Next Step
**Sprint 1.2** — Docker Compose for MySQL (core profile): two schemas (`identity_db`, `learning_db`), two DB users, initialization scripts, and a health check confirming both schemas are reachable.

---

## Sprint 1.2 — Docker Compose for MySQL (core profile)
**Date:** 2026-11-18
**Goal:** Bring up MySQL 8.4 with two schemas (`identity_db`, `learning_db`), two service users, and an initialization script; confirm both schemas are reachable.

### Completed
- `docker-compose.yml` — MySQL 8.4 service under `core` profile, `b2b-mysql` container, `b2b-mysql-data` named volume, port 3306, healthcheck via `mysqladmin ping`
- `infra/mysql/init/01-init.sh` — creates `identity_db` and `learning_db` (utf8mb4), creates `identity_user` and `learning_user` with passwords injected from env vars, grants all privileges on respective schemas
- `.env.example` — `MYSQL_ROOT_PASSWORD`, `IDENTITY_DB_PASSWORD`, `LEARNING_DB_PASSWORD` with placeholder values
- `.env` — copied from `.env.example` (gitignored)

### Commands Run
```shell
cp .env.example .env
docker compose --profile core up -d
# Container b2b-mysql Started

docker compose ps
# b2b-mysql   mysql:8.4   ...   Up 12 seconds (healthy)   0.0.0.0:3306->3306/tcp

docker exec b2b-mysql mysql -u identity_user -pchangeme_identity identity_db -e "SELECT 1"
# 1

docker exec b2b-mysql mysql -u learning_user -pchangeme_learning learning_db -e "SELECT 1"
# 1
```

### Acceptance Check
- [x] `docker compose --profile core up -d` → container started
- [x] `docker compose ps` → `b2b-mysql` status `healthy`
- [x] `identity_user` connects to `identity_db` → `SELECT 1` returns `1`
- [x] `learning_user` connects to `learning_db` → `SELECT 1` returns `1`

### Unresolved Issues
- None

### Next Step
**Sprint 1.3** — Create the `identity-service` Maven module: Spring Boot 3.3.4, Spring Data JPA, Flyway, MySQL connector, Eureka client, Spring Security, Bean Validation. First migration: `V1__create_users_roles_tables.sql`. Goal: service starts, registers with Eureka at `http://localhost:8761`, and Flyway applies the migration cleanly against `identity_db`.

---

## Sprint 1.3 — identity-service module: JPA, Flyway, Eureka, Security scaffold
**Date:** 2026-11-23
**Goal:** Create the `identity-service` Maven module; apply V1 Flyway migration against `identity_db`; register with Eureka.

### Completed
- `services/identity-service/pom.xml` — spring-boot-starter-web, data-jpa, security, validation, actuator, eureka-client, flyway-core, flyway-mysql, mysql-connector-j
- `IdentityServiceApplication.java` — standard Spring Boot entry point
- `config/SecurityConfig.java` — stateless, CSRF disabled, all endpoints permitted (temporary; Sprint 2 replaces with JWT filter per ADR-002)
- `application.yml` — port 8081, identity_db datasource, `ddl-auto: validate`, Flyway enabled, Eureka defaultZone localhost:8761
- `db/migration/V1__create_accounts_roles_tables.sql` — creates `roles` (seeded ADMIN/INSTRUCTOR/STUDENT), `accounts`, `account_roles` FK join table
- Root `pom.xml` updated to include `services/identity-service` module

### Commands Run
```shell
export JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home
./mvnw package -pl services/identity-service -am -q
# BUILD SUCCESS

./mvnw spring-boot:run -pl services/discovery-server   # background
./mvnw spring-boot:run -pl services/identity-service   # background, IDENTITY_DB_PASSWORD=changeme_identity

curl http://localhost:8081/actuator/health
# {"status":"UP"}

# Flyway log:
# Successfully applied 1 migration to schema `identity_db`, now at version v1

curl http://localhost:8761/eureka/apps/IDENTITY-SERVICE
# <status>UP</status>

docker exec b2b-mysql mysql -u identity_user -pchangeme_identity identity_db \
  -e "SHOW TABLES; SELECT name FROM roles;"
# Tables: account_roles, accounts, flyway_schema_history, roles
# Roles:  ADMIN, INSTRUCTOR, STUDENT
```

### Acceptance Check
- [x] `./mvnw package -pl services/identity-service -am` → BUILD SUCCESS
- [x] `curl http://localhost:8081/actuator/health` → `{"status":"UP"}`
- [x] Flyway log → "Successfully applied 1 migration to schema `identity_db`, now at version v1"
- [x] `curl http://localhost:8761/eureka/apps/IDENTITY-SERVICE` → `<status>UP</status>`
- [x] `SHOW TABLES` in identity_db → accounts, roles, account_roles, flyway_schema_history

### Unresolved Issues
- Flyway warns MySQL 8.4 is newer than the tested version (max tested: 8.1). No functional impact observed; note for future Flyway upgrade.

### Next Step
**Sprint 1.4** — see below.

---

## Sprint 1.4 — Auth endpoints: BCrypt + RSA JWT, login + me
**Date:** 2026-11-25
**Goal:** Implement `POST /api/auth/login` and `GET /api/auth/me` in identity-service with BCrypt password verification and RS256 JWT (1-hour access token).

### Completed
- `pom.xml` — added `jjwt-api 0.12.6`, `jjwt-impl`, `jjwt-jackson` (runtime)
- `domain/Role.java` — JPA entity mapping `roles` table
- `domain/Account.java` — JPA entity mapping `accounts` table with `@ManyToMany` roles via `account_roles`; `@PrePersist`/`@PreUpdate` manage timestamps
- `repository/AccountRepository.java` — `findByUsername`, `existsByUsername`
- `repository/RoleRepository.java` — `findByName`
- `dto/LoginRequest.java`, `LoginResponse.java`, `MeResponse.java` — Java records
- `service/JwtService.java` — generates 2048-bit RSA key pair on startup; `generateToken` (RS256, 1 hour); `validateAndParse` via `Jwts.parser().verifyWith(publicKey)`
- `service/AccountService.java` — implements `UserDetailsService`; loads account by username, maps roles to `SimpleGrantedAuthority` (no "ROLE_" prefix, roles stored as plain `ADMIN`/`INSTRUCTOR`/`STUDENT`)
- `config/JwtAuthenticationFilter.java` — `OncePerRequestFilter`; extracts Bearer token, validates, sets `SecurityContextHolder`
- `web/AuthController.java` — `POST /api/auth/login` authenticates via `AuthenticationManager`, issues JWT; `GET /api/auth/me` reads from Security context
- `init/DataInitializer.java` — `ApplicationRunner`; seeds `admin / Admin@123` (BCrypt-encoded) with ADMIN role if not already present
- `config/SecurityConfig.java` — replaced temporary open config: `BCryptPasswordEncoder` bean, `AuthenticationManager` bean, JWT filter wired before `UsernamePasswordAuthenticationFilter`, `/api/auth/login` + `/actuator/**` permitted, all else authenticated
- `application.yml` — added `app.jwt.expiration-ms: 3600000`

### Commands Run
```shell
export JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home
export IDENTITY_DB_PASSWORD=changeme_identity
mvn -pl services/identity-service compile -q
# BUILD SUCCESS

mvn -pl services/identity-service spring-boot:run -q &

curl http://localhost:8081/actuator/health
# {"status":"UP"}

curl -s -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'
# {"token":"eyJhbGciOiJSUzI1NiJ9...","username":"admin","roles":["ADMIN"]}

curl -s http://localhost:8081/api/auth/me \
  -H "Authorization: Bearer <token>"
# {"username":"admin","roles":["ADMIN"]}

curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/auth/me
# 403  (unauthenticated — endpoint is protected)
```

### Acceptance Check
- [x] `mvn -pl services/identity-service compile -q` → BUILD SUCCESS
- [x] `POST /api/auth/login` with `admin / Admin@123` → 200 + signed RS256 JWT containing `username` and `roles`
- [x] `GET /api/auth/me` with valid JWT → `{"username":"admin","roles":["ADMIN"]}`
- [x] `GET /api/auth/me` without token → 403 (endpoint protected)

### Unresolved Issues
- Spring Security returns 403 (not 401) for unauthenticated requests without an explicit `AuthenticationEntryPoint`. Acceptable for Sprint 1.4; configure proper 401 in a later sprint.
- RSA key pair is generated fresh on each startup (tokens are invalidated on restart). Acceptable for dev; Sprint 2 will load from a persistent keystore.

### Next Step
**Sprint 1.5** — Gateway service or learning-service module (TBD).

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
