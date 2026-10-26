import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { EMBER, FACE_SIZE, markPainter, MIST, NIGHT, PAPER } from './lib/carli-mark.mjs';
import { encodePng } from './lib/png.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = join(root, 'public', 'splash');
const iosDir = join(root, 'ios', 'App', 'App', 'Assets.xcassets', 'Splash.imageset');
const indexHtml = join(root, 'src', 'index.html');
const facePoints = 96;
const iosSplashSize = 2732;
const iosSplashScale = 3;

const themes = {
  light: { background: MIST, face: EMBER, eyes: PAPER },
  dark: { background: NIGHT, face: EMBER, eyes: PAPER },
};

const render = (width, height, facePixels, theme) =>
  encodePng(width, height, 3, markPainter({ ...theme, markSize: (facePixels * 100) / FACE_SIZE, width, height }));

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

mkdirSync(outputDir, { recursive: true });
const links = [];
for (const device of devices) {
  const width = device.width * device.ratio;
  const height = device.height * device.ratio;
  for (const [name, theme] of Object.entries(themes)) {
    const file = `splash-${width}x${height}-${name}.png`;
    writeFileSync(join(outputDir, file), render(width, height, facePoints * device.ratio, theme));
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

mkdirSync(iosDir, { recursive: true });
const iosImages = [];
for (const [name, theme] of Object.entries(themes)) {
  const file = `splash-${iosSplashSize}-${name}.png`;
  writeFileSync(join(iosDir, file), render(iosSplashSize, iosSplashSize, facePoints * iosSplashScale, theme));
  iosImages.push({
    idiom: 'universal',
    filename: file,
    ...(name === 'dark' ? { appearances: [{ appearance: 'luminosity', value: 'dark' }] } : {}),
  });
}
const iosContents = { images: iosImages, info: { author: 'xcode', version: 1 } };
writeFileSync(join(iosDir, 'Contents.json'), `${JSON.stringify(iosContents, null, 2)}\n`);
