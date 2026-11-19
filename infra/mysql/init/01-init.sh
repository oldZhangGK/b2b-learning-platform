#!/bin/bash
set -e

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
  CREATE DATABASE IF NOT EXISTS identity_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

  CREATE DATABASE IF NOT EXISTS learning_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

  CREATE USER IF NOT EXISTS 'identity_user'@'%'
    IDENTIFIED BY '${IDENTITY_DB_PASSWORD}';
  GRANT ALL PRIVILEGES ON identity_db.* TO 'identity_user'@'%';

  CREATE USER IF NOT EXISTS 'learning_user'@'%'
    IDENTIFIED BY '${LEARNING_DB_PASSWORD}';
  GRANT ALL PRIVILEGES ON learning_db.* TO 'learning_user'@'%';

  FLUSH PRIVILEGES;
EOSQL
