import postgres from 'postgres';
import { drizzle } from 'drizzle-orm/postgres-js';
import * as schema from './schema.js';
import { log } from '../utils/log.js';

let _db: ReturnType<typeof drizzle<typeof schema>>;
let _sql: ReturnType<typeof postgres>;

export function getDb() {
  if (!_db) throw new Error('DB not initialized');
  return _db;
}

export async function initDb() {
  const url = process.env.NEON_DATABASE_URL;
  if (!url) throw new Error('NEON_DATABASE_URL is not set');

  _sql = postgres(url, { ssl: 'require', max: 5, prepare: false });
  _db = drizzle(_sql, { schema });

  const stmts = [
    `DO $$ BEGIN CREATE TYPE key_status AS ENUM ('UNUSED','ACTIVE','EXPIRED','REVOKED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$`,
    `DO $$ BEGIN CREATE TYPE key_type AS ENUM ('PERMANENT','HOURLY','DAILY','WEEKLY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$`,
    `DO $$ BEGIN CREATE TYPE hwid_period AS ENUM ('DAILY','WEEKLY','MONTHLY','UNLIMITED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$`,
    `CREATE TABLE IF NOT EXISTS licenses (
      key TEXT PRIMARY KEY,
      status key_status NOT NULL DEFAULT 'UNUSED',
      type key_type NOT NULL,
      duration INTEGER,
      expires_at TIMESTAMPTZ,
      hwid TEXT,
      max_hwid_resets INTEGER NOT NULL DEFAULT 1,
      user_hwid_reset_count INTEGER NOT NULL DEFAULT 0,
      hwid_period hwid_period NOT NULL DEFAULT 'WEEKLY',
      last_hwid_reset_at TIMESTAMPTZ,
      account_limit INTEGER NOT NULL DEFAULT 1,
      label TEXT,
      created_by TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `CREATE TABLE IF NOT EXISTS license_owners (
      id TEXT PRIMARY KEY,
      license_key TEXT NOT NULL REFERENCES licenses(key) ON DELETE CASCADE,
      discord_user_id TEXT NOT NULL,
      assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `CREATE TABLE IF NOT EXISTS whitelist (
      discord_user_id TEXT PRIMARY KEY,
      claimed_vip BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `CREATE TABLE IF NOT EXISTS trial_claims (
      discord_user_id TEXT PRIMARY KEY,
      license_key TEXT NOT NULL,
      claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `CREATE TABLE IF NOT EXISTS pending_tickets (
      discord_user_id TEXT PRIMARY KEY,
      channel_id TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `CREATE TABLE IF NOT EXISTS roblox_accounts (
      id TEXT PRIMARY KEY,
      license_key TEXT NOT NULL REFERENCES licenses(key) ON DELETE CASCADE,
      roblox_username TEXT NOT NULL,
      bound_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
  ];

  for (const stmt of stmts) {
    await _sql.unsafe(stmt);
  }

  log.info('Database initialized');
}
