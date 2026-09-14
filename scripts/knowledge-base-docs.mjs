import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const docDir = path.join(root, 'staging/knowledge-base');
const escape = (s) =>
  s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
function walk(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]));
}
const modulePaths = [
  'apps/portal/src/features/knowledge-base',
  'apps/portal/src/app/(portal)/biblioteca',
  'apps/portal/src/app/api/knowledge-base',
];
const files = modulePaths
  .flatMap((p) => walk(path.join(root, p)))
  .concat(
    ["supabase/migrations/0043_m22_knowledge_base.sql","scripts/knowledge-base-docs.mjs","apps/portal/tests/knowledge-base.test.ts","packages/knowledge-base-validation/tests/knowledge-base.test.mjs","packages/knowledge-base-validation/package.json","packages/knowledge-base-validation/package-lock.json","supabase/preflight/0043_m22_knowledge_base_preflight.sql","supabase/rollback/0043_m22_knowledge_base.rollback.sql","supabase/verification/m22_g4_post_apply.sql"].map(
      (p) => path.join(root, p),
    ),
  )
  .sort();
const hashes = Object.fromEntries(
  files.map((p) => [
    path.relative(root, p).replaceAll('\\', '/'),
    createHash('sha256').update(fs.readFileSync(p, 'utf8').replaceAll('\r\n', '\n')).digest('hex'),
  ]),
);
const manifest = JSON.stringify({ version: '0.1.0', files: hashes }, null, 2) + '\n';
const check = process.argv.includes('--check');
let failed = false;
function output(p, value) {
  if (check) {
    if (
      !fs.existsSync(p) ||
      fs.readFileSync(p, 'utf8').replaceAll('\r\n', '\n') !== value.replaceAll('\r\n', '\n')
    ) {
      console.error('KB_DOCS_STALE: ' + path.relative(root, p));
      failed = true;
    }
  } else fs.writeFileSync(p, value);
}
output(path.join(docDir, 'manifest.json'), manifest);
for (const file of walk(docDir).filter((p) => p.endsWith('.md'))) {
  const md = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
  const title = md.split('\n')[0].replace(/^# /, '');
  const html =
    '<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' +
    escape(title) +
    '</title><style>body{margin:40px auto;padding:0 24px;max-width:1050px;font:16px/1.7 system-ui;color:#14222d}header{border-bottom:5px solid #f6851f}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit}footer{border-top:2px solid #1e9680}</style><header><h1>' +
    escape(title) +
    '</h1><p>Versão 0.1.0 · Fonte Markdown canônica · Conteúdo equivalente</p></header><main><pre>' +
    escape(md) +
    '</pre></main><footer>ConnectionCyber · Tecnologia que traz conhecimento e gestão</footer></html>\n';
  output(file.replace(/\.md$/, '.html'), html);
  if (path.basename(file).startsWith('RELATORIO-M22-')) {
    output(path.join(root, path.basename(file)), md);
    output(path.join(root, path.basename(file).replace(/\.md$/, '.html')), html);
  }
}

const statusFile = path.join(docDir, 'STATUS-M22.md');
if (fs.existsSync(statusFile)) {
  const status = fs.readFileSync(statusFile, 'utf8').replaceAll('\r\n', '\n');
  const start = '<!-- M22-KB-START -->',
    end = '<!-- M22-KB-END -->';
  for (const ext of ['md', 'html']) {
    const master = path.join(root, 'STATUS-MESTRE-DESENVOLVIMENTO.' + ext);
    const existing = fs.readFileSync(master, 'utf8');
    const block =
      start +
      '\n' +
      (ext === 'md'
        ? status
        : '<section id="m22-knowledge-base"><pre style="white-space:pre-wrap">' +
          escape(status) +
          '</pre></section>') +
      '\n' +
      end;
    const begin = existing.indexOf(start),
      finish = existing.indexOf(end);
    const result =
      begin >= 0 && finish >= begin
        ? existing.slice(0, begin) + block + existing.slice(finish + end.length)
        : ext === 'html'
          ? existing.replace('</body>', block + '\n</body>')
          : existing + '\n' + block + '\n';
    output(master, result);
  }
}

if (failed) process.exitCode = 1;
else console.log(check ? 'KB_DOCS_OK' : 'KB_DOCS_GENERATED');
