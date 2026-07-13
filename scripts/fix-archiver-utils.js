const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', 'node_modules', 'archiver-utils');
const destDir = path.join(__dirname, '..', 'node_modules', 'zip-stream', 'node_modules');
const dest = path.join(destDir, 'archiver-utils');

if (fs.existsSync(src) && !fs.existsSync(dest)) {
  fs.mkdirSync(destDir, { recursive: true });
  fs.cpSync(src, dest, { recursive: true });
}
