'use strict';

const path = require('path');
const fs = require('fs');

function runMigrations(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at INTEGER NOT NULL DEFAULT (unixepoch())
    )
  `);

  const migrationsDir = path.join(__dirname, 'migrations');
  if (!fs.existsSync(migrationsDir)) return;

  const files = fs
    .readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.js'))
    .sort();

  const applied = new Set(
    db.prepare('SELECT version FROM schema_migrations').pluck().all(),
  );

  for (const file of files) {
    const version = path.basename(file, '.js');
    if (applied.has(version)) continue;

    const migration = require(path.join(migrationsDir, file));
    const run = db.transaction(() => {
      migration.up(db);
      db.prepare('INSERT INTO schema_migrations (version) VALUES (?)').run(version);
    });
    run();
  }
}

module.exports = { runMigrations };
