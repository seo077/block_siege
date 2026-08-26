import { mkdtemp, mkdir, writeFile, readFile, readdir, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join, resolve, relative } from 'node:path';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

async function snapshot(root) {
  const entries = [];
  async function visit(directory) {
    for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
      const path = join(directory, entry.name), name = relative(root, path).replaceAll('\\', '/');
      if (entry.isDirectory()) { entries.push({ name, type: 'directory' }); await visit(path); }
      else { const bytes = await readFile(path); entries.push({ name, type: 'file', size: bytes.length, sha256: sha256(bytes) }); }
    }
  }
  await visit(root);
  return JSON.stringify(entries);
}

async function seed(evidence, label) {
  await mkdir(join(evidence, 'live-assets', 'nested'), { recursive: true });
  const files = {
    '.nojekyll': '',
    'attestation.bundle.jsonl': `bundle-${label}\n`,
    'evidence-payload.json': JSON.stringify({ authenticated: true, label }),
    'evidence-payload.sha256': `${'a'.repeat(64)}  evidence-payload.json\n`,
    'result.json': JSON.stringify({ verdict: 'PASS', label }),
    'hud.png': Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, ...Buffer.from(label)]),
    'live-build-manifest.json': JSON.stringify({ source_commit: label }),
    'live-assets/index.js': `asset-${label}`,
    'live-assets/nested/game.pck': `pack-${label}`,
  };
  for (const [name, bytes] of Object.entries(files)) await writeFile(join(evidence, name), bytes);
}

function runProbe(argv) {
  return new Promise((ok, no) => {
    const child = spawn(process.execPath, argv, { cwd: process.cwd(), stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
    child.stdout.on('data', value => { stdout += value; }); child.stderr.on('data', value => { stderr += value; });
    child.once('error', no); child.once('exit', code => ok({ code, stdout, stderr }));
  });
}

async function main() {
  const root = await mkdtemp(join(tmpdir(), 'block-siege-atomic-evidence-'));
  try {
    const runner = resolve('tests/web/run_browser_regression.mjs');
    const probes = [
      { name: 'REQ-014', extra: ['--oracle-spec', resolve('.interlocking/work/001-core-combat-economy/SPEC.md')] },
      { name: 'REQ-017', extra: [] },
    ];
    for (const probe of probes) {
      const evidence = join(root, probe.name); await seed(evidence, probe.name);
      const before = await snapshot(evidence);
      const result = await runProbe([runner, '--base-url', 'invalid://deployed-probe', '--requirements', probe.name, '--evidence', evidence, ...probe.extra]);
      assert(result.code !== 0, `${probe.name} failed probe unexpectedly exited zero: ${result.stdout}`);
      assert(await snapshot(evidence) === before, `${probe.name} failed probe changed the authenticated evidence tree`);
    }
    console.log('PASS: REQ-014 and REQ-017 failed deployed probes preserve authenticated evidence trees byte-for-byte');
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

main().catch(error => { console.error(`FAIL: ${error.message}`); process.exitCode = 1; });
