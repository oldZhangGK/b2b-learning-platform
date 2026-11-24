-- Sprint 1.3: initial identity schema
-- Roles are seeded here and never modified by the application.
-- accounts.password_hash stores BCrypt-encoded passwords (Sprint 2).

CREATE TABLE roles (
    id   INT          AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(20)  NOT NULL UNIQUE
);

INSERT INTO roles (name) VALUES ('ADMIN'), ('INSTRUCTOR'), ('STUDENT');

CREATE TABLE accounts (
    id            BIGINT       AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
);

CREATE TABLE account_roles (
    account_id BIGINT NOT NULL,
    role_id    INT    NOT NULL,
    PRIMARY KEY (account_id, role_id),
    CONSTRAINT fk_ar_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
    CONSTRAINT fk_ar_role    FOREIGN KEY (role_id)    REFERENCES roles (id)    ON DELETE CASCADE
);
