import { mkdirSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const outputDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'icons');
const ink = [13, 13, 13];
const paper = [255, 255, 255];
const supersampling = 4;

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

const crc32 = (buffer) => {
  let crc = 0xffffffff;
  for (const byte of buffer) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
};

const chunk = (type, data) => {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
};

const encodePng = (size, pixels) => {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header.writeUInt8(8, 8);
  header.writeUInt8(6, 9);
  const raw = Buffer.alloc((size * 4 + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    pixels.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
};

const inRect = (x, y, x0, y0, x1, y1) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
const inCircle = (x, y, cx, cy, r) => (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2;

const isLetter = (x, y) => {
  const stem = inRect(x, y, 34, 26, 45, 74);
  const bowlOuter = inRect(x, y, 34, 26, 51, 56) || inCircle(x, y, 51, 41, 15);
  const bowlInner = inRect(x, y, 40, 37, 51, 45) || inCircle(x, y, 51, 41, 4);
  return stem || (bowlOuter && !bowlInner);
};

const shapes = {
  circle: (x, y) => inCircle(x, y, 50, 50, 50),
  square: () => true,
};

const render = ({ size, background, letterScale }) => {
  const pixels = Buffer.alloc(size * size * 4);
  for (let py = 0; py < size; py++) {
    for (let px = 0; px < size; px++) {
      let backgroundHits = 0;
      let letterHits = 0;
      for (let sy = 0; sy < supersampling; sy++) {
        for (let sx = 0; sx < supersampling; sx++) {
          const x = ((px + (sx + 0.5) / supersampling) / size) * 100;
          const y = ((py + (sy + 0.5) / supersampling) / size) * 100;
          if (!shapes[background](x, y)) continue;
          backgroundHits++;
          const lx = 50 + (x - 50) / letterScale;
          const ly = 50 + (y - 50) / letterScale;
          if (isLetter(lx, ly)) letterHits++;
        }
      }
      const samples = supersampling * supersampling;
      const alpha = backgroundHits / samples;
      const letterRatio = backgroundHits ? letterHits / backgroundHits : 0;
      const offset = (py * size + px) * 4;
      for (let c = 0; c < 3; c++) {
        pixels[offset + c] = Math.round(ink[c] * (1 - letterRatio) + paper[c] * letterRatio);
      }
      pixels[offset + 3] = Math.round(alpha * 255);
    }
  }
  return encodePng(size, pixels);
};

const icons = [
  { file: 'icon-192.png', size: 192, background: 'circle', letterScale: 1.25 },
  { file: 'icon-512.png', size: 512, background: 'circle', letterScale: 1.25 },
  { file: 'maskable-192.png', size: 192, background: 'square', letterScale: 0.95 },
  { file: 'maskable-512.png', size: 512, background: 'square', letterScale: 0.95 },
  { file: 'apple-touch-icon.png', size: 180, background: 'square', letterScale: 1.1 },
  { file: 'favicon-32.png', size: 32, background: 'circle', letterScale: 1.3 },
];

mkdirSync(outputDir, { recursive: true });
for (const icon of icons) {
  writeFileSync(join(outputDir, icon.file), render(icon));
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="50" r="50" fill="#0D0D0D"/><path fill="#FFFFFF" transform="translate(50 50) scale(1.25) translate(-50 -50)" fill-rule="evenodd" d="M34 26h17a15 15 0 0 1 0 30h-6v18H34Z M45 37v8h6a4 4 0 0 0 0-8Z"/></svg>\n`;
writeFileSync(join(outputDir, 'icon.svg'), svg);
