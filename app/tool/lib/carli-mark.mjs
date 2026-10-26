export const INK = [0, 0, 0];
export const EMBER = [229, 6, 63];
export const MIST = [245, 245, 247];
export const PAPER = [255, 255, 255];
export const NIGHT = [0, 0, 0];

const FACE = { x0: 12, y0: 12, x1: 88, y1: 88, radius: 28 };
const EYES = [
  { cx: 39, cy: 47, rx: 5.5, ry: 9 },
  { cx: 61, cy: 47, rx: 5.5, ry: 9 },
];
export const FACE_SIZE = FACE.x1 - FACE.x0;

const inRoundedRect = (x, y, { x0, y0, x1, y1, radius }) => {
  const dx = Math.max(x0 + radius - x, 0, x - (x1 - radius));
  const dy = Math.max(y0 + radius - y, 0, y - (y1 - radius));
  return x >= x0 && x <= x1 && y >= y0 && y <= y1 && dx * dx + dy * dy <= radius * radius;
};

const inEllipse = (x, y, { cx, cy, rx, ry }) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;

export const markAt = (x, y) => {
  if (!inRoundedRect(x, y, FACE)) return 'none';
  return EYES.some((eye) => inEllipse(x, y, eye)) ? 'eye' : 'face';
};

export const mix = (from, to, ratio) => from.map((value, index) => Math.round(value * (1 - ratio) + to[index] * ratio));

export const markSvg = ({ face = '#E5063F', eyes = '#FFFFFF', background } = {}) => {
  const backdrop = background ? `<rect width="100" height="100" fill="${background}"/>` : '';
  const eyeShapes = EYES.map(({ cx, cy, rx, ry }) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${eyes}"/>`).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${backdrop}<rect x="${FACE.x0}" y="${FACE.y0}" width="${FACE_SIZE}" height="${FACE_SIZE}" rx="${FACE.radius}" fill="${face}"/>${eyeShapes}</svg>\n`;
};

const SAMPLES = 4;

export const sampleMark = (localX, localY, pixelSize) => {
  let face = 0;
  let eye = 0;
  for (let sy = 0; sy < SAMPLES; sy++) {
    for (let sx = 0; sx < SAMPLES; sx++) {
      const hit = markAt(localX + ((sx + 0.5) / SAMPLES) * pixelSize, localY + ((sy + 0.5) / SAMPLES) * pixelSize);
      if (hit === 'face') face++;
      if (hit === 'eye') eye++;
    }
  }
  const total = SAMPLES * SAMPLES;
  return { coverage: (face + eye) / total, eyeRatio: face + eye ? eye / (face + eye) : 0 };
};

export const markPainter = ({ background, face, eyes, markSize, width, height }) => {
  const left = (width - markSize) / 2;
  const top = (height - markSize) / 2;
  const unit = 100 / markSize;
  return (px, py) => {
    const localX = (px - left) * unit;
    const localY = (py - top) * unit;
    if (localX < -unit || localX > 100 || localY < -unit || localY > 100) return background;
    const { coverage, eyeRatio } = sampleMark(localX, localY, unit);
    return mix(background, mix(face, eyes, eyeRatio), coverage);
  };
};
