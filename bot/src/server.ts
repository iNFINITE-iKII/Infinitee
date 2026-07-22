import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { getDb } from './db/index.js';
import { licenses, robloxAccounts } from './db/schema.js';
import { eq } from 'drizzle-orm';
import { log } from './utils/log.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Saat dist/index.mjs berjalan, __dirname = <root>/bot/dist
// Games ada di <root>/games
const GAMES_DIR = path.resolve(__dirname, '../../games');

// URL lama yang di-hardcode di semua file Lua
const RAILWAY_URL = 'https://xifil-hub-production.up.railway.app';

/**
 * Kembalikan base URL server ini berdasarkan header request.
 * Urutan prioritas:
 *   1. Env var SERVER_BASE_URL (override manual)
 *   2. LOADER_URL env var (potong path-nya, ambil origin saja)
 *   3. Header X-Forwarded-Proto + X-Forwarded-Host (proxy/Replit)
 *   4. Header Host biasa
 */
function getServerBaseUrl(req: http.IncomingMessage): string {
  if (process.env.SERVER_BASE_URL) return process.env.SERVER_BASE_URL.replace(/\/$/, '');

  if (process.env.LOADER_URL) {
    try {
      const u = new URL(process.env.LOADER_URL);
      return u.origin;
    } catch {/* fallthrough */}
  }

  const proto =
    (req.headers['x-forwarded-proto'] as string | undefined)?.split(',')[0]?.trim() ?? 'https';
  const host =
    (req.headers['x-forwarded-host'] as string | undefined)?.split(',')[0]?.trim() ??
    req.headers.host ??
    'localhost:3000';

  return `${proto}://${host}`;
}

/**
 * Ganti semua referensi ke Railway URL di dalam konten Lua dengan
 * URL server yang sedang berjalan, supaya script tetap bekerja
 * di platform manapun (Railway → Replit → dst).
 */
function patchLuaUrls(content: string, req: http.IncomingMessage): string {
  const base = getServerBaseUrl(req);
  if (base === RAILWAY_URL) return content; // sudah benar, tidak perlu patch
  return content.replaceAll(RAILWAY_URL, base);
}

function parseQuery(url: string): Record<string, string> {
  const q: Record<string, string> = {};
  const idx = url.indexOf('?');
  if (idx === -1) return q;
  url
    .slice(idx + 1)
    .split('&')
    .forEach((part) => {
      const [k, v] = part.split('=');
      if (k) q[decodeURIComponent(k)] = decodeURIComponent(v ?? '');
    });
  return q;
}

function json(res: http.ServerResponse, status: number, data: object) {
  const body = JSON.stringify(data);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(body);
}

function lua(res: http.ServerResponse, content: string) {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(content);
}

// ── /api/license/check ────────────────────────────────────────────────────────
async function handleLicenseCheck(
  req: http.IncomingMessage,
  res: http.ServerResponse,
  query: Record<string, string>,
) {
  const key  = (query.key  ?? '').trim().toUpperCase();
  const hwid = (query.hwid ?? '').trim();

  if (!key || !hwid) {
    return json(res, 400, { status: 'error', message: 'Parameter key dan hwid wajib diisi.' });
  }

  try {
    const db = getDb();
    const license = await db.query.licenses.findFirst({
      where: eq(licenses.key, key),
    });

    if (!license) {
      return json(res, 200, { status: 'error', message: 'Key tidak ditemukan.' });
    }

    if (license.status === 'REVOKED') {
      return json(res, 200, { status: 'error', message: 'Key telah direvoke.' });
    }

    if (license.status === 'EXPIRED') {
      return json(res, 200, { status: 'error', message: 'Key telah kadaluarsa.' });
    }

    // Cek kadaluarsa berdasarkan waktu
    if (license.expiresAt && new Date() > license.expiresAt) {
      await db.update(licenses).set({ status: 'EXPIRED' }).where(eq(licenses.key, key));
      return json(res, 200, { status: 'error', message: 'Key telah kadaluarsa.' });
    }

    // Ambil daftar akun Roblox yang sudah terikat ke key ini
    const boundAccounts = await db.query.robloxAccounts.findMany({
      where: eq(robloxAccounts.licenseKey, key),
    });

    // Cek apakah HWID ini sudah terdaftar
    const alreadyBound = boundAccounts.some(
      (a) => a.id === hwid || a.robloxUsername === hwid,
    );

    if (alreadyBound) {
      // Aktifkan jika masih UNUSED
      if (license.status === 'UNUSED') {
        await db.update(licenses).set({ status: 'ACTIVE' }).where(eq(licenses.key, key));
      }
      return json(res, 200, { status: 'success', message: 'Key valid.' });
    }

    // HWID baru — cek limit akun
    if (boundAccounts.length >= license.accountLimit) {
      return json(res, 200, {
        status: 'error',
        message: `Key sudah mencapai batas ${license.accountLimit} akun.`,
      });
    }

    // Daftarkan HWID baru
    const robloxId = hwid.startsWith('rbx-acct-') ? hwid.slice('rbx-acct-'.length) : hwid;
    await db
      .insert(robloxAccounts)
      .values({
        id: `${key}-${hwid}`,
        licenseKey: key,
        robloxUsername: robloxId,
        boundAt: new Date(),
      })
      .onConflictDoNothing();

    // Aktifkan key jika masih UNUSED
    if (license.status === 'UNUSED') {
      await db
        .update(licenses)
        .set({ status: 'ACTIVE', hwid })
        .where(eq(licenses.key, key));
    }

    return json(res, 200, { status: 'success', message: 'Key valid dan berhasil terdaftar.' });
  } catch (err) {
    log.error({ err }, 'License check error');
    return json(res, 500, { status: 'error', message: 'Internal server error.' });
  }
}

// ── /api/lua/loader ───────────────────────────────────────────────────────────
function handleLoader(
  req: http.IncomingMessage,
  res: http.ServerResponse,
  query: Record<string, string>,
) {
  const game = (query.game ?? '').replace(/[^a-zA-Z0-9_-]/g, '');
  if (!game) return json(res, 400, { error: 'Parameter game wajib diisi.' });

  const filePath = path.join(GAMES_DIR, `${game}.lua`);
  if (!fs.existsSync(filePath)) {
    return json(res, 404, { error: `Game "${game}" tidak ditemukan.` });
  }

  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return lua(res, patchLuaUrls(content, req));
  } catch {
    return json(res, 500, { error: 'Gagal membaca file Lua.' });
  }
}

// ── /api/lua/module/:game/:file ───────────────────────────────────────────────
function handleModule(
  req: http.IncomingMessage,
  res: http.ServerResponse,
  pathname: string,
) {
  // pathname contoh: /api/lua/module/ironsoulv1/ui/tab_farm.lua
  const prefix = '/api/lua/module/';
  const rest = pathname.slice(prefix.length); // ironsoulv1/ui/tab_farm.lua

  // Sanitasi: larang path traversal
  const normalized = path.normalize(rest);
  if (normalized.startsWith('..')) {
    return json(res, 400, { error: 'Path tidak valid.' });
  }

  const filePath = path.join(GAMES_DIR, normalized);

  // Pastikan file masih di dalam GAMES_DIR
  if (!filePath.startsWith(GAMES_DIR)) {
    return json(res, 403, { error: 'Akses ditolak.' });
  }

  if (!fs.existsSync(filePath)) {
    return json(res, 404, { error: `Module "${rest}" tidak ditemukan.` });
  }

  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return lua(res, patchLuaUrls(content, req));
  } catch {
    return json(res, 500, { error: 'Gagal membaca file Lua.' });
  }
}

// ── Router utama ──────────────────────────────────────────────────────────────
export function startServer(port: number = 3000) {
  const server = http.createServer((req, res) => {
    const rawUrl  = req.url ?? '/';
    const idx     = rawUrl.indexOf('?');
    const pathname = idx === -1 ? rawUrl : rawUrl.slice(0, idx);
    const query   = parseQuery(rawUrl);

    if (pathname === '/api/license/check') {
      return handleLicenseCheck(req, res, query);
    }

    if (pathname === '/api/lua/loader') {
      return handleLoader(req, res, query);
    }

    if (pathname.startsWith('/api/lua/module/')) {
      return handleModule(req, res, pathname);
    }

    // Health check
    if (pathname === '/' || pathname === '/health') {
      return json(res, 200, { status: 'ok' });
    }

    return json(res, 404, { error: 'Not found.' });
  });

  server.listen(port, () => {
    log.info(`HTTP server berjalan di port ${port}`);
  });

  return server;
}
