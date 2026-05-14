'use strict';

const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
const { runMigrations } = require('./migrate');

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
  runMigrations(db);
  return db;
}

module.exports = { initDb, getDb };
