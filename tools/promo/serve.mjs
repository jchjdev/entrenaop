// Sirve exclusivamente los dos builds de demo en loopback, nunca el repositorio.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css' };

for (const [name, port] of [['athlete', 8780], ['trainer', 8781]]) {
  const root = resolve(repo, `build/promo/${name}-web`);
  createServer(async (request, response) => {
    if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405).end(); return; }
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      const file = resolve(root, `.${pathname}`, pathname.endsWith('/') ? 'index.html' : '');
      if (!file.startsWith(root + sep)) { response.writeHead(404).end(); return; }
      const body = await readFile(file);
      response.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream', 'Content-Length': body.length, 'Cache-Control': 'no-store' });
      response.end(request.method === 'HEAD' ? undefined : body);
    } catch { response.writeHead(404).end(); }
  }).listen(port, '127.0.0.1', () => process.stdout.write(`Demo ${name}: http://127.0.0.1:${port}/\n`));
}
