import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

const [indexPath, outputPath] = process.argv.slice(2);
const html = readFileSync(indexPath, 'utf8');
const inlineScripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)].map((match) => match[1]);
const hashes = inlineScripts
  .filter((content) => content.trim().length > 0)
  .map((content) => `'sha256-${createHash('sha256').update(content, 'utf8').digest('base64')}'`);

writeFileSync(outputPath, [...new Set(hashes)].join(' '));
console.log(`CSP inline script hashes: ${hashes.length ? hashes.join(' ') : '(none)'}`);
