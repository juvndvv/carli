import { readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const frontend = join(root, '..', 'frontend', 'src', 'app');
const output = join(root, 'lib', 'ui', 'icon_names.dart');
const hugeicons = process.argv[2] ?? join(homedir(), '.pub-cache/hosted/pub.dev/hugeicons-1.2.0/lib/styles/stroke_rounded.dart');

const available = new Set([...readFileSync(hugeicons, 'utf8').matchAll(/static const List<List<dynamic>> (\w+)\b/g)].map((m) => m[1]));
const toDart = (node) => node.replace(/Icon$/, '').replace(/^./, (c) => c.toLowerCase());

const entries = new Map();
const add = (name, node) => {
  const dart = toDart(node);
  if (!available.has(dart)) throw new Error(`Missing Flutter icon ${dart} for ${name}`);
  entries.set(name, dart);
};

const base = readFileSync(join(frontend, 'ui', 'icon', 'icon-set.ts'), 'utf8');
for (const [, name, node, aliases] of base.matchAll(/\['([\w-]+)',\s*(\w+)(?:,\s*\[([^\]]*)\])?\]/g)) {
  add(name, node);
  for (const alias of (aliases ?? '').matchAll(/'([\w-]+)'/g)) add(alias[1], node);
}

const finance = readFileSync(join(frontend, 'modules', 'finance', 'ui', 'finance-icons.ts'), 'utf8');
const block = finance.slice(finance.indexOf('FINANCE_ICON_NODES = {'), finance.indexOf('};', finance.indexOf('FINANCE_ICON_NODES')));
for (const [, quoted, bare, node] of block.matchAll(/(?:'([\w-]+)'|(\w+)):\s*(\w+)/g)) add(quoted ?? bare, node);

const lines = [...entries.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([name, dart]) => `  '${name}': HugeIconsStrokeRounded.${dart},`);
writeFileSync(
  output,
  `import 'package:hugeicons/styles/stroke_rounded.dart';

import 'icon.dart';

const carliIconNames = <String, CarliIconData>{
${lines.join('\n')}
};

CarliIconData carliIconNamed(String? name, {CarliIconData fallback = HugeIconsStrokeRounded.circleDashed}) =>
    carliIconNames[name] ?? fallback;
`,
);
console.log(`${entries.size} icons`);
