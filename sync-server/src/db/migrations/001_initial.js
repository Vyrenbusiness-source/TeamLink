'use strict';

function addColumnIfMissing(db, table, column, definition) {
  const cols = db.pragma(`table_info(${table})`).map((r) => r.name);
  if (!cols.includes(column)) {
    db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
  }
}

module.exports = {
  up(db) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id            TEXT    PRIMARY KEY,
        name          TEXT    NOT NULL,
        email         TEXT    UNIQUE NOT NULL,
        password_hash TEXT    NOT NULL,
        avatar_url    TEXT,
        created_at    INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        updated_at    INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
      );

      CREATE TABLE IF NOT EXISTS projects (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        owner_id    TEXT    NOT NULL REFERENCES users(id),
        description TEXT,
        created_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        updated_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
      );

      CREATE TABLE IF NOT EXISTS users_projects (
        id         TEXT,
        user_id    TEXT    NOT NULL REFERENCES users(id),
        project_id TEXT    NOT NULL REFERENCES projects(id),
        role       TEXT    NOT NULL DEFAULT 'member',
        invited_by TEXT    REFERENCES users(id),
        joined_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        PRIMARY KEY (user_id, project_id)
      );

      CREATE TABLE IF NOT EXISTS tasks (
        id          TEXT    PRIMARY KEY,
        project_id  TEXT    NOT NULL REFERENCES projects(id),
        title       TEXT    NOT NULL,
        description TEXT,
        status      TEXT    NOT NULL DEFAULT 'open',
        priority    TEXT,
        assignee_id TEXT    REFERENCES users(id),
        deadline    INTEGER,
        updated_by  TEXT    REFERENCES users(id),
        created_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        updated_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
      );

      CREATE TABLE IF NOT EXISTS notes (
        id          TEXT    PRIMARY KEY,
        project_id  TEXT    NOT NULL REFERENCES projects(id),
        title       TEXT,
        content     TEXT    NOT NULL DEFAULT '',
        created_by  TEXT    REFERENCES users(id),
        updated_by  TEXT    REFERENCES users(id),
        created_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        updated_at  INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
      );

      CREATE TABLE IF NOT EXISTS messages (
        id           TEXT    PRIMARY KEY,
        sender_id    TEXT    NOT NULL REFERENCES users(id),
        recipient_id TEXT    NOT NULL,
        project_id   TEXT,
        content      TEXT    NOT NULL,
        read_at      INTEGER,
        created_at   INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        updated_at   INTEGER
      );

      CREATE TABLE IF NOT EXISTS invite_tokens (
        token      TEXT    PRIMARY KEY,
        project_id TEXT    REFERENCES projects(id),
        role       TEXT    NOT NULL DEFAULT 'member',
        created_by TEXT    REFERENCES users(id),
        created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
        expires_at INTEGER,
        used_by    TEXT    REFERENCES users(id),
        used_at    INTEGER
      );
    `);

    // Patch columns for DBs created by the pre-migration schema.js
    addColumnIfMissing(db, 'users', 'avatar_url', 'TEXT');
    addColumnIfMissing(db, 'users', 'updated_at', 'INTEGER NOT NULL DEFAULT (unixepoch() * 1000)');

    addColumnIfMissing(db, 'projects', 'owner_id', 'TEXT REFERENCES users(id)');
    addColumnIfMissing(db, 'projects', 'description', 'TEXT');
    addColumnIfMissing(db, 'projects', 'updated_at', 'INTEGER NOT NULL DEFAULT (unixepoch() * 1000)');

    addColumnIfMissing(db, 'users_projects', 'id', 'TEXT');
    addColumnIfMissing(db, 'users_projects', 'invited_by', 'TEXT REFERENCES users(id)');
    addColumnIfMissing(db, 'users_projects', 'joined_at', 'INTEGER NOT NULL DEFAULT (unixepoch() * 1000)');
    addColumnIfMissing(db, 'users_projects', 'updated_at', 'INTEGER NOT NULL DEFAULT (unixepoch() * 1000)');

    addColumnIfMissing(db, 'tasks', 'description', 'TEXT');
    addColumnIfMissing(db, 'tasks', 'priority', 'TEXT');
    addColumnIfMissing(db, 'tasks', 'updated_by', 'TEXT REFERENCES users(id)');

    addColumnIfMissing(db, 'notes', 'title', 'TEXT');
    addColumnIfMissing(db, 'notes', 'created_by', 'TEXT REFERENCES users(id)');
    addColumnIfMissing(db, 'notes', 'created_at', 'INTEGER NOT NULL DEFAULT (unixepoch() * 1000)');

    addColumnIfMissing(db, 'messages', 'project_id', 'TEXT');
    addColumnIfMissing(db, 'messages', 'read_at', 'INTEGER');
    addColumnIfMissing(db, 'messages', 'updated_at', 'INTEGER');
  },
};
