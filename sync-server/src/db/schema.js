const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

let db;

function getDb() {
  if (!db) throw new Error('Database not initialized');
  return db;
}

function initDb() {
  const DB_PATH =
    process.env.DB_PATH || path.join(__dirname, '../../data/teamlink.db');
  const isMemory = DB_PATH === ':memory:';
  if (!isMemory) {
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  }
  db = new Database(DB_PATH);
  if (!isMemory) {
    db.pragma('journal_mode = WAL');
  }
  db.pragma('foreign_keys = ON');
  applySchema(db);
  return db;
}

function applySchema(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE TABLE IF NOT EXISTS users_projects (
      user_id TEXT NOT NULL REFERENCES users(id),
      project_id TEXT NOT NULL REFERENCES projects(id),
      role TEXT NOT NULL DEFAULT 'member',
      PRIMARY KEY (user_id, project_id)
    );

    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL REFERENCES projects(id),
      title TEXT NOT NULL,
      deadline INTEGER,
      assignee_id TEXT REFERENCES users(id),
      status TEXT NOT NULL DEFAULT 'open',
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      updated_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL REFERENCES projects(id),
      content TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
      updated_by TEXT REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      sender_id TEXT NOT NULL REFERENCES users(id),
      recipient_id TEXT NOT NULL REFERENCES users(id),
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE TABLE IF NOT EXISTS invite_tokens (
      token TEXT PRIMARY KEY,
      project_id TEXT REFERENCES projects(id),
      role TEXT NOT NULL DEFAULT 'member',
      created_by TEXT REFERENCES users(id),
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      expires_at INTEGER,
      used_by TEXT REFERENCES users(id),
      used_at INTEGER
    );
  `);
}

module.exports = { initDb, getDb };
