export type KeyType = 'PERMANENT' | 'HOURLY' | 'DAILY' | 'WEEKLY';
export type HwidPeriod = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'UNLIMITED';

export function calcExpiresAt(type: KeyType, duration: number | null): Date | null {
  if (type === 'PERMANENT') return null;
  const now = Date.now();
  const d = duration ?? 1;
  switch (type) {
    case 'HOURLY':  return new Date(now + d * 60 * 60 * 1000);
    case 'DAILY':   return new Date(now + d * 24 * 60 * 60 * 1000);
    case 'WEEKLY':  return new Date(now + d * 7 * 24 * 60 * 60 * 1000);
  }
}

export function isExpired(expiresAt: Date | null): boolean {
  if (!expiresAt) return false;
  return expiresAt < new Date();
}

export function getEffectiveStatus(
  status: string,
  expiresAt: Date | null,
): 'UNUSED' | 'ACTIVE' | 'EXPIRED' | 'REVOKED' {
  if (status === 'REVOKED') return 'REVOKED';
  if (status === 'UNUSED') return 'UNUSED';
  if (status === 'ACTIVE' && isExpired(expiresAt)) return 'EXPIRED';
  if (status === 'EXPIRED') return 'EXPIRED';
  return 'ACTIVE';
}

export function statusEmoji(status: 'UNUSED' | 'ACTIVE' | 'EXPIRED' | 'REVOKED'): string {
  return { UNUSED: '🔵', ACTIVE: '🟢', EXPIRED: '🟠', REVOKED: '🔴' }[status];
}

export function typeLabel(type: KeyType, duration: number | null): string {
  if (type === 'PERMANENT') return 'Permanent ♾️';
  return `${type === 'HOURLY' ? 'Hourly' : type === 'DAILY' ? 'Daily' : 'Weekly'}-${duration}`;
}

export function discordTimestamp(date: Date): string {
  return `<t:${Math.floor(date.getTime() / 1000)}:F>`;
}

export function hwidCooldownMs(period: HwidPeriod): number {
  switch (period) {
    case 'DAILY':     return 24 * 60 * 60 * 1000;
    case 'WEEKLY':    return 7 * 24 * 60 * 60 * 1000;
    case 'MONTHLY':   return 30 * 24 * 60 * 60 * 1000;
    case 'UNLIMITED': return 0;
  }
}

export function hwidPeriodLabel(period: HwidPeriod): string {
  return { DAILY: 'Per Hari', WEEKLY: 'Per Minggu', MONTHLY: 'Per Bulan', UNLIMITED: 'Tanpa Cooldown' }[period];
}
