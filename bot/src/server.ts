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

// URL lama yang di-hardcode di semua file Lua.
// Nilai ini tetap dipakai sebagai marker ketika file Lua masih berisi URL
// Railway lama, lalu diganti ke origin request yang sedang melayani file.
const RAILWAY_URL = 'https://xifil-hub-production.up.railway.app';
const RAW_GITHUB_GAME_BASE =
  'https://raw.githubusercontent.com/iNFINITE-iKII/Infinitee/main/games/mininghubv1/';
const RAW_GITHUB_TEMPLATE_BASE = `${RAW_GITHUB_GAME_BASE}templategui/`;

// Nama game publik dapat berbeda dari nama file internal di repository.
// Alias ini menjaga URL loader tetap singkat tanpa menduplikasi entry point Lua.
const GAME_ALIASES: Record<string, string> = {
  mountainamine: 'mininghubv1',
};

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
 * Ganti semua URL runtime di dalam konten Lua dengan endpoint server yang
 * sedang berjalan. Loader entry point sebelumnya mengambil modul lanjutan
 * langsung dari raw.githubusercontent.com. Itu membuat loadstring dari
 * endpoint ini bergantung pada repo/branch publik dan dapat berhenti sebelum
 * GUI dibuat. Semua modul sekarang diambil lewat router server yang sama.
 */
function patchLuaUrls(content: string, req: http.IncomingMessage): string {
  const base = getServerBaseUrl(req);
  const gameModuleBase = `${base}/api/lua/module/mininghubv1/`;
  const templateModuleBase = `${gameModuleBase}templategui/`;

  return content
    .replaceAll(RAILWAY_URL, base)
    // Replace the longer template URL first so it is not partially replaced
    // by the generic game base replacement below.
    .replaceAll(RAW_GITHUB_TEMPLATE_BASE, templateModuleBase)
    .replaceAll(RAW_GITHUB_GAME_BASE, gameModuleBase);
}

/**
 * Roblox executors tidak konsisten meneruskan User-Agent. Sebagian
 * mengirim "Roblox", sebagian memakai User-Agent executor, dan sebagian
 * mengosongkannya. Endpoint ini memang hanya menyajikan source loader publik,
 * jadi User-Agent bukan kontrol akses yang valid dan tidak boleh dipakai untuk
 * menghentikan eksekusi sebelum GUI dibuat.
 */
function parseQuery(url: string): Record<string, string> {
  const q: Record<string, string> = {};
  const idx = url.indexOf('?');
  if (idx === -1) return q;
  url
    .slice(idx + 1)
    .split('&')
    .forEach((part) => {
      const separator = part.indexOf('=');
      const rawKey = separator === -1 ? part : part.slice(0, separator);
      const rawValue = separator === -1 ? '' : part.slice(separator + 1);
      if (!rawKey) return;
      try {
        q[decodeURIComponent(rawKey)] = decodeURIComponent(rawValue);
      } catch {
        // Ignore malformed query fragments instead of crashing the request.
      }
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

    // Normalkan hwid ke robloxUsername (strip prefix rbx-acct- jika ada)
    const robloxId = hwid.startsWith('rbx-acct-') ? hwid.slice('rbx-acct-'.length) : hwid;

    // Cek apakah HWID ini sudah terdaftar
    // id tersimpan sebagai "${key}-${hwid}", username tersimpan tanpa prefix rbx-acct-
    const alreadyBound = boundAccounts.some(
      (a) => a.id === `${key}-${hwid}` || a.robloxUsername === robloxId,
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
  const requestedGame = (query.game ?? '').replace(/[^a-zA-Z0-9_-]/g, '').toLowerCase();
  if (!requestedGame) return json(res, 400, { error: 'Parameter game wajib diisi.' });

  const game = GAME_ALIASES[requestedGame] ?? requestedGame;
  const filePath = path.join(GAMES_DIR, `${game}.lua`);
  if (!fs.existsSync(filePath)) {
    return json(res, 404, { error: `Game "${requestedGame}" tidak ditemukan.` });
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
  if (filePath !== GAMES_DIR && !filePath.startsWith(`${GAMES_DIR}${path.sep}`)) {
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
