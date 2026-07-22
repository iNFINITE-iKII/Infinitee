import crypto from 'crypto';

// Charset tanpa karakter ambigu (I, 1, O, 0)
const CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function randomChar(): string {
  return CHARSET[crypto.randomInt(0, CHARSET.length)]!;
}

function randomGroup(): string {
  return Array.from({ length: 4 }, randomChar).join('');
}

export function generateKey(): string {
  return `${randomGroup()}-${randomGroup()}-${randomGroup()}-${randomGroup()}`;
}

export function generateKeys(amount: number): string[] {
  return Array.from({ length: amount }, generateKey);
}

export function generateId(): string {
  return crypto.randomUUID();
}

export function normalizeKey(key: string): string {
  return key.trim().toUpperCase();
}
