import { mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { EMBER, FACE_SIZE, INK, markPainter, PAPER } from '../../frontend/scripts/lib/carli-mark.mjs';
import { encodePng } from '../../frontend/scripts/lib/png.mjs';

const assets = join(dirname(fileURLToPath(import.meta.url)), '..', 'ios', 'Runner', 'Assets.xcassets');
const opaque = (color) => [...color, 255];
const markSizeFor = (facePixels) => (facePixels * 100) / FACE_SIZE;
const json = (value) => `${JSON.stringify(value, null, 2)}\n`;
const info = { author: 'xcode', version: 1 };

const resetDir = (dir) => {
  mkdirSync(dir, { recursive: true });
  for (const file of readdirSync(dir)) rmSync(join(dir, file));
};

const paint = (size, channels, options) =>
  encodePng(size, size, channels, markPainter({ ...options, width: size, height: size }));

const iconDir = join(assets, 'AppIcon.appiconset');
const iconSize = 1024;
resetDir(iconDir);
writeFileSync(
  join(iconDir, 'AppIcon-1024.png'),
  paint(iconSize, 3, {
    background: opaque(INK),
    face: opaque(EMBER),
    eyes: opaque(PAPER),
    markSize: markSizeFor(iconSize * 0.62),
  }),
);
writeFileSync(
  join(iconDir, 'Contents.json'),
  json({ images: [{ filename: 'AppIcon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }], info }),
);

const launchDir = join(assets, 'LaunchImage.imageset');
const facePoints = 96;
resetDir(launchDir);
const scales = [1, 2, 3];
for (const scale of scales) {
  const size = facePoints * scale;
  writeFileSync(
    join(launchDir, `LaunchImage@${scale}x.png`),
    paint(size, 4, {
      background: [...INK, 0],
      face: opaque(EMBER),
      eyes: opaque(PAPER),
      markSize: markSizeFor(size),
    }),
  );
}
writeFileSync(
  join(launchDir, 'Contents.json'),
  json({
    images: scales.map((scale) => ({ filename: `LaunchImage@${scale}x.png`, idiom: 'universal', scale: `${scale}x` })),
    info,
  }),
);

const srgb = (hex) => ({
  'color-space': 'srgb',
  components: {
    alpha: '1.000',
    red: `0x${hex.slice(0, 2)}`,
    green: `0x${hex.slice(2, 4)}`,
    blue: `0x${hex.slice(4, 6)}`,
  },
});
const backgroundDir = join(assets, 'LaunchBackground.colorset');
resetDir(backgroundDir);
writeFileSync(
  join(backgroundDir, 'Contents.json'),
  json({
    colors: [
      { color: srgb('F5F5F7'), idiom: 'universal' },
      { appearances: [{ appearance: 'luminosity', value: 'dark' }], color: srgb('000000'), idiom: 'universal' },
    ],
    info,
  }),
);
