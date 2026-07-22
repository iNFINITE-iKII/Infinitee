import { build } from 'esbuild';

await build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outfile: 'dist/index.mjs',
  sourcemap: true,
  external: [],
  banner: {
    js: [
      `import { createRequire } from 'module';`,
      `import { fileURLToPath as __ftp } from 'url';`,
      `import { dirname as __dn } from 'path';`,
      `const require = createRequire(import.meta.url);`,
      `const __filename = __ftp(import.meta.url);`,
      `const __dirname = __dn(__filename);`,
    ].join(' '),
  },
});

console.log('Build complete.');
