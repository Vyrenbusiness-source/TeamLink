exports.up = function (db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id          TEXT    PRIMARY KEY,
      user_id     TEXT    NOT NULL,
      token_hash  TEXT    NOT NULL UNIQUE,
      expires_at  INTEGER NOT NULL,
      revoked_at  INTEGER,
      created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
  `);
};
