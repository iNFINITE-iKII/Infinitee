import {
  pgTable,
  text,
  integer,
  timestamp,
  boolean,
  pgEnum,
} from 'drizzle-orm/pg-core';

export const keyStatusEnum = pgEnum('key_status', ['UNUSED', 'ACTIVE', 'EXPIRED', 'REVOKED']);
export const keyTypeEnum = pgEnum('key_type', ['PERMANENT', 'HOURLY', 'DAILY', 'WEEKLY']);
export const hwidPeriodEnum = pgEnum('hwid_period', ['DAILY', 'WEEKLY', 'MONTHLY', 'UNLIMITED']);

export const licenses = pgTable('licenses', {
  key: text('key').primaryKey(),
  status: keyStatusEnum('status').notNull().default('UNUSED'),
  type: keyTypeEnum('type').notNull(),
  duration: integer('duration'),
  expiresAt: timestamp('expires_at'),
  hwid: text('hwid'),
  maxHwidResets: integer('max_hwid_resets').notNull().default(1),
  userHwidResetCount: integer('user_hwid_reset_count').notNull().default(0),
  hwidPeriod: hwidPeriodEnum('hwid_period').notNull().default('WEEKLY'),
  lastHwidResetAt: timestamp('last_hwid_reset_at'),
  accountLimit: integer('account_limit').notNull().default(1),
  label: text('label'),
  createdBy: text('created_by').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

export const licenseOwners = pgTable('license_owners', {
  id: text('id').primaryKey(),
  licenseKey: text('license_key')
    .notNull()
    .references(() => licenses.key, { onDelete: 'cascade' }),
  discordUserId: text('discord_user_id').notNull(),
  assignedAt: timestamp('assigned_at').notNull().defaultNow(),
});

export const whitelist = pgTable('whitelist', {
  discordUserId: text('discord_user_id').primaryKey(),
  claimedVip: boolean('claimed_vip').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

export const trialClaims = pgTable('trial_claims', {
  discordUserId: text('discord_user_id').primaryKey(),
  licenseKey: text('license_key').notNull(),
  claimedAt: timestamp('claimed_at').notNull().defaultNow(),
});

export const pendingTickets = pgTable('pending_tickets', {
  discordUserId: text('discord_user_id').primaryKey(),
  channelId: text('channel_id').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

export const robloxAccounts = pgTable('roblox_accounts', {
  id: text('id').primaryKey(),
  licenseKey: text('license_key')
    .notNull()
    .references(() => licenses.key, { onDelete: 'cascade' }),
  robloxUsername: text('roblox_username').notNull(),
  boundAt: timestamp('bound_at').notNull().defaultNow(),
});
