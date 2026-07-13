const fs = require('fs');
const path = require('path');

const sizes = [
  { file: 'icon-16.png', size: 16 },
  { file: 'icon-48.png', size: 48 },
  { file: 'icon-256.png', size: 256 },
];

const images = sizes.map((s) => ({
  size: s.size,
  data: fs.readFileSync(path.join(__dirname, s.file)),
}));

const headerSize = 6;
const entrySize = 16;
let offset = headerSize + entrySize * images.length;

const header = Buffer.alloc(headerSize);
header.writeUInt16LE(0, 0); // reserved
header.writeUInt16LE(1, 2); // type: icon
header.writeUInt16LE(images.length, 4);

const entries = [];
for (const img of images) {
  const entry = Buffer.alloc(entrySize);
  const dim = img.size >= 256 ? 0 : img.size; // 0 means 256 in ICO format
  entry.writeUInt8(dim, 0); // width
  entry.writeUInt8(dim, 1); // height
  entry.writeUInt8(0, 2); // color count
  entry.writeUInt8(0, 3); // reserved
  entry.writeUInt16LE(1, 4); // planes
  entry.writeUInt16LE(32, 6); // bit count
  entry.writeUInt32LE(img.data.length, 8); // bytes in resource
  entry.writeUInt32LE(offset, 12); // image offset
  offset += img.data.length;
  entries.push(entry);
}

const out = Buffer.concat([header, ...entries, ...images.map((i) => i.data)]);
fs.writeFileSync(path.join(__dirname, 'icon.ico'), out);
console.log('Wrote icon.ico', out.length, 'bytes');
