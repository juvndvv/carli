import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { EMBER, FACE_SIZE, INK, markPainter, markSvg, PAPER } from './lib/carli-mark.mjs';
import { encodePng } from './lib/png.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const webDir = join(root, 'public', 'icons');
const iosDir = join(root, 'ios', 'App', 'App', 'Assets.xcassets', 'AppIcon.appiconset');

const transparent = [...INK, 0];
const opaque = (color) => [...color, 255];

const faceOnly = (size) => ({
  channels: 4,
  background: transparent,
  face: opaque(EMBER),
  eyes: opaque(PAPER),
  markSize: (size * 100) / FACE_SIZE,
});

const faceOnTile = (size, faceShare, channels = 4) => ({
  channels,
  background: opaque(INK),
  face: opaque(EMBER),
  eyes: opaque(PAPER),
  markSize: (size * faceShare * 100) / FACE_SIZE,
});

const icons = [
  { dir: webDir, file: 'icon-192.png', size: 192, ...faceOnly(192) },
  { dir: webDir, file: 'icon-512.png', size: 512, ...faceOnly(512) },
  { dir: webDir, file: 'favicon-32.png', size: 32, ...faceOnly(32) },
  { dir: webDir, file: 'maskable-192.png', size: 192, ...faceOnTile(192, 0.56) },
  { dir: webDir, file: 'maskable-512.png', size: 512, ...faceOnTile(512, 0.56) },
  { dir: webDir, file: 'apple-touch-icon.png', size: 180, ...faceOnTile(180, 0.62, 3) },
  { dir: iosDir, file: 'AppIcon-512@2x.png', size: 1024, ...faceOnTile(1024, 0.62, 3) },
];

mkdirSync(webDir, { recursive: true });
for (const { dir, file, size, channels, ...colors } of icons) {
  const paint = markPainter({ ...colors, width: size, height: size });
  writeFileSync(join(dir, file), encodePng(size, size, channels, paint));
}

writeFileSync(join(webDir, 'icon.svg'), markSvg());
