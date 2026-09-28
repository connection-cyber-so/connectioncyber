import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const files = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' }).split('\0').filter(Boolean);
const excluded = new Set(['scripts/scan-tracked-secrets.mjs']);
const patterns = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /sb_secret_[A-Za-z0-9_-]{20,}/,
  /eyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/,
  /postgres(?:ql)?:\/\/[^\s:[\]]+:[^\s@[\]]+@[^\s]+/i,
];
const findings = [];

for (const file of files) {
  if (excluded.has(file) || file.endsWith('package-lock.json')) continue;
  const material = fs.readFileSync(file);
  if (material.includes(0)) continue;
  const text = material.toString('utf8');
  if (patterns.some((pattern) => pattern.test(text))) findings.push(file);
}

if (findings.length) {
  console.error(`TRACKED_SECRET_SCAN_FAILED files=${findings.join(',')}`);
  process.exit(1);
}
console.log(`TRACKED_SECRET_SCAN_OK files=${files.length}`);
