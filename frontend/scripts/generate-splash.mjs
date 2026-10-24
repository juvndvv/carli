import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = join(root, 'public', 'splash');
const indexHtml = join(root, 'src', 'index.html');
const supersampling = 4;
const iconPoints = 96;
const letterScale = 1.25;

const themes = {
  light: { background: [255, 255, 255], circle: [13, 13, 13], letter: [255, 255, 255] },
  dark: { background: [33, 33, 33], circle: [255, 255, 255], letter: [13, 13, 13] },
};

const devices = [
  { width: 440, height: 956, ratio: 3 },
  { width: 402, height: 874, ratio: 3 },
  { width: 430, height: 932, ratio: 3 },
  { width: 393, height: 852, ratio: 3 },
  { width: 428, height: 926, ratio: 3 },
  { width: 390, height: 844, ratio: 3 },
  { width: 375, height: 812, ratio: 3 },
  { width: 414, height: 896, ratio: 3 },
  { width: 414, height: 896, ratio: 2 },
  { width: 414, height: 736, ratio: 3 },
  { width: 375, height: 667, ratio: 2 },
  { width: 320, height: 568, ratio: 2 },
  { width: 1024, height: 1366, ratio: 2 },
  { width: 834, height: 1194, ratio: 2 },
  { width: 820, height: 1180, ratio: 2 },
  { width: 810, height: 1080, ratio: 2 },
  { width: 768, height: 1024, ratio: 2 },
  { width: 744, height: 1133, ratio: 2 },
];

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

const encodePng = (width, height, rows) => {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header.writeUInt8(8, 8);
  header.writeUInt8(2, 9);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(rows, { level: 9 })),
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

const mix = (from, to, ratio) => from.map((value, index) => Math.round(value * (1 - ratio) + to[index] * ratio));

const render = (width, height, iconSize, theme) => {
  const stride = width * 3 + 1;
  const rows = Buffer.alloc(stride * height);
  const left = Math.floor((width - iconSize) / 2);
  const top = Math.floor((height - iconSize) / 2);
  for (let py = 0; py < height; py++) {
    rows[py * stride] = 0;
    for (let px = 0; px < width; px++) {
      let color = theme.background;
      if (px >= left && px < left + iconSize && py >= top && py < top + iconSize) {
        let circleHits = 0;
        let letterHits = 0;
        for (let sy = 0; sy < supersampling; sy++) {
          for (let sx = 0; sx < supersampling; sx++) {
            const x = ((px - left + (sx + 0.5) / supersampling) / iconSize) * 100;
            const y = ((py - top + (sy + 0.5) / supersampling) / iconSize) * 100;
            if (!inCircle(x, y, 50, 50, 50)) continue;
            circleHits++;
            if (isLetter(50 + (x - 50) / letterScale, 50 + (y - 50) / letterScale)) letterHits++;
          }
        }
        const samples = supersampling * supersampling;
        const ink = mix(theme.circle, theme.letter, circleHits ? letterHits / circleHits : 0);
        color = mix(theme.background, ink, circleHits / samples);
      }
      const offset = py * stride + 1 + px * 3;
      rows[offset] = color[0];
      rows[offset + 1] = color[1];
      rows[offset + 2] = color[2];
    }
  }
  return encodePng(width, height, rows);
};

mkdirSync(outputDir, { recursive: true });
const links = [];
for (const device of devices) {
  const width = device.width * device.ratio;
  const height = device.height * device.ratio;
  for (const [name, theme] of Object.entries(themes)) {
    const file = `splash-${width}x${height}-${name}.png`;
    writeFileSync(join(outputDir, file), render(width, height, iconPoints * device.ratio, theme));
    const media = [
      `(device-width: ${device.width}px)`,
      `(device-height: ${device.height}px)`,
      `(-webkit-device-pixel-ratio: ${device.ratio})`,
      '(orientation: portrait)',
      `(prefers-color-scheme: ${name})`,
    ].join(' and ');
    links.push(`  <link rel="apple-touch-startup-image" media="${media}" href="splash/${file}">`);
  }
}

const startMarker = '  <!-- splash:start -->';
const endMarker = '  <!-- splash:end -->';
const html = readFileSync(indexHtml, 'utf8');
const block = [startMarker, ...links, endMarker].join('\n');
const pattern = new RegExp(`${startMarker.trim()}[\\s\\S]*?${endMarker.trim()}`);
const updated = pattern.test(html)
  ? html.replace(pattern, block.trim())
  : html.replace('  <link rel="manifest"', `${block}\n  <link rel="manifest"`);
writeFileSync(indexHtml, updated);
