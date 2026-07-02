const http = require('http');
const fs = require('fs');
const path = require('path');

const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript' };
const root = __dirname;

http.createServer((req, res) => {
  let p = req.url === '/' ? '/index.html' : req.url;
  const filePath = path.join(root, decodeURIComponent(p));
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    const ext = path.extname(filePath);
    res.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8000, () => console.log('Server running at http://localhost:8000/'));
