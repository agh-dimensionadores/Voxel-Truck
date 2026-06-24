import http from 'node:http';
import https from 'node:https';

const target = new URL(process.argv[2] ?? 'https://aghbackend.onrender.com');
const port = Number(process.argv[3] ?? 18765);
const upstreamTimeoutMs = 60_000;

function corsHeaders(req) {
  const origin = req.headers.origin;
  return {
    ...(origin
      ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' }
      : { 'Access-Control-Allow-Origin': '*' }),
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
    'Access-Control-Max-Age': '600',
    'Access-Control-Allow-Private-Network': 'true',
  };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders(req));
    res.end();
    return;
  }

  let body = Buffer.alloc(0);
  try {
    body = await readBody(req);
  } catch (error) {
    res.writeHead(400, { ...corsHeaders(req), 'content-type': 'text/plain; charset=utf-8' });
    res.end(error.message);
    return;
  }

  const upstreamHeaders = {};
  if (req.headers.authorization) upstreamHeaders.Authorization = req.headers.authorization;
  if (req.headers['content-type']) upstreamHeaders['Content-Type'] = req.headers['content-type'];
  if (req.headers.accept) upstreamHeaders.Accept = req.headers.accept;
  if (body.length > 0) upstreamHeaders['Content-Length'] = body.length;

  const upstream = (target.protocol === 'https:' ? https : http).request(
    {
      protocol: target.protocol,
      hostname: target.hostname,
      port: target.port || (target.protocol === 'https:' ? 443 : 80),
      path: req.url,
      method: req.method,
      headers: upstreamHeaders,
    },
    (up) => {
      res.writeHead(up.statusCode ?? 502, {
        ...corsHeaders(req),
        'content-type': up.headers['content-type'] ?? 'application/json',
      });
      up.pipe(res);
    },
  );

  upstream.setTimeout(upstreamTimeoutMs, () => {
    upstream.destroy(new Error('Upstream timeout'));
  });

  upstream.on('error', (error) => {
    if (!res.headersSent) {
      res.writeHead(502, {
        ...corsHeaders(req),
        'content-type': 'text/plain; charset=utf-8',
      });
    }
    res.end(error.message);
  });

  if (body.length > 0) {
    upstream.write(body);
  }
  upstream.end();
});

server.listen(port, '127.0.0.1', () => {
  console.log('==> Proxy API dev');
  console.log(`    Local:  http://127.0.0.1:${port}`);
  console.log(`    Remoto: ${target.origin}`);
  console.log('    Ctrl+C para detener');
});
