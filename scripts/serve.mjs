import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = path.resolve(__dirname, '..');

const ROOT = process.env.GODOT_WEB_DIR
    ? path.resolve(process.env.GODOT_WEB_DIR)
    : path.join(PROJECT_DIR, 'export', 'web');

const PORT = Number(process.env.PORT || 5997);
const HOST = process.env.HOST || '0.0.0.0';

// Godot HTML5 exports need a "secure context" (HTTPS or localhost).
// When a cert/key pair is present we serve HTTPS; otherwise fall back to HTTP.
const CERT_FILE = process.env.TLS_CERT || path.join(PROJECT_DIR, 'certs', 'cert.pem');
const KEY_FILE = process.env.TLS_KEY || path.join(PROJECT_DIR, 'certs', 'key.pem');
const USE_TLS = fs.existsSync(CERT_FILE) && fs.existsSync(KEY_FILE);

const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream',
    '.zip': 'application/zip',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.webp': 'image/webp',
    '.json': 'application/json; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.ico': 'image/x-icon',
    '.txt': 'text/plain; charset=utf-8',
};

function isolationHeaders() {
    return {
        // Required for Godot 4 web builds that use SharedArrayBuffer (threads)
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
        'Cross-Origin-Resource-Policy': 'cross-origin',
    };
}

function contentTypeFor(filePath) {
    const lower = filePath.toLowerCase();
    // Godot emits names like index.audio.worklet.js -> .js handles it
    for (const ext of Object.keys(MIME)) {
        if (lower.endsWith(ext)) return MIME[ext];
    }
    return 'application/octet-stream';
}

const requestHandler = (req, res) => {
    let urlPath;
    try {
        urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    } catch {
        res.writeHead(400, isolationHeaders());
        res.end('Bad request');
        return;
    }

    let filePath = path.normalize(path.join(ROOT, urlPath));
    if (!filePath.startsWith(ROOT)) {
        res.writeHead(403, isolationHeaders());
        res.end('Forbidden');
        return;
    }

    fs.stat(filePath, (err, st) => {
        if (!err && st.isDirectory()) {
            filePath = path.join(filePath, 'index.html');
        }

        fs.stat(filePath, (err2, st2) => {
            const headers = {
                ...isolationHeaders(),
                'Cache-Control': 'no-store',
            };

            if (err2 || !st2.isFile()) {
                headers['Content-Type'] = 'text/plain; charset=utf-8';
                res.writeHead(404, headers);
                res.end(`404 Not found: ${urlPath}\n\nNo web export at ${ROOT}.\nRun: npm run export\n`);
                return;
            }

            headers['Content-Type'] = contentTypeFor(filePath);
            headers['Content-Length'] = st2.size;
            res.writeHead(200, headers);

            if (req.method === 'HEAD') {
                res.end();
                return;
            }

            const stream = fs.createReadStream(filePath);
            stream.on('error', () => res.destroy());
            stream.pipe(res);
        });
    });
};

const server = USE_TLS
    ? https.createServer({ cert: fs.readFileSync(CERT_FILE), key: fs.readFileSync(KEY_FILE) }, requestHandler)
    : http.createServer(requestHandler);

const SCHEME = USE_TLS ? 'https' : 'http';

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error('');
        console.error(`  Port ${PORT} is already in use — a server is probably already running.`);
        console.error(`  Open ${SCHEME}://${HOST}:${PORT}/ , or stop the old one:`);
        console.error(`    pkill -f scripts/serve.mjs`);
        console.error(`  Or use a different port:`);
        console.error(`    PORT=6000 npm start`);
        console.error('');
        process.exit(0);
    }
    throw err;
});

server.listen(PORT, HOST, () => {
    const exists = fs.existsSync(path.join(ROOT, 'index.html'));
    console.log('');
    console.log('  Horrorscratcher - Godot web host');
    console.log(`  ➜  ${SCHEME}://${HOST}:${PORT}/`);
    console.log(`  ➜  Serving: ${ROOT}`);
    console.log(`  ➜  Build present: ${exists ? 'yes' : 'NO (run: npm run export)'}`);
    console.log(`  ➜  TLS: ${USE_TLS ? `yes (${CERT_FILE})` : 'no — Godot needs HTTPS or localhost!'}`);
    console.log('  ➜  COOP/COEP: same-origin / require-corp');
    console.log('');
});
