import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdtemp, stat, mkdir } from 'node:fs/promises';
import { resolve, relative, isAbsolute, join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const REPOSITORY = 'seo077/block_siege';
const WORKFLOW = '.github/workflows/pages.yml';
const REF = 'refs/heads/master';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const fail = message => { throw new Error(message); };
const assert = (value, message) => { if (!value) fail(message); };
const json = async path => JSON.parse(await readFile(path, 'utf8'));

function args(argv) {
  const out = {};
  const flags = new Set(['record-trusted-root-sha256', 'require-source-ancestor-of-head', 'require-manifest-bytes-from-attested-head']);
  for (let i = 2; i < argv.length; i++) {
    assert(argv[i].startsWith('--'), `invalid argument ${argv[i]}`);
    const key = argv[i].slice(2);
    if (flags.has(key)) out[key] = true;
    else { assert(argv[i + 1] && !argv[i + 1].startsWith('--'), `missing value for --${key}`); out[key] = argv[++i]; }
  }
  for (const key of ['requirements', 'trusted-root', 'trusted-root-origin']) assert(out[key], `missing --${key}`);
  return out;
}

async function command(name, argv, cwd) {
  return new Promise((ok, no) => {
    const child = spawn(name, argv, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => stdout += chunk); child.stderr.on('data', chunk => stderr += chunk);
    child.once('error', no); child.once('exit', code => code === 0 ? ok(stdout.trim()) : no(new Error(`${name} ${argv.join(' ')} failed: ${stderr || stdout}`)));
  });
}

async function commandBytes(name, argv, cwd) {
  return new Promise((ok, no) => {
    const child = spawn(name, argv, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    const chunks = []; let stderr = '';
    child.stdout.on('data', chunk => chunks.push(chunk)); child.stderr.on('data', chunk => stderr += chunk);
    child.once('error', no); child.once('exit', code => code === 0 ? ok(Buffer.concat(chunks)) : no(new Error(`${name} ${argv.join(' ')} failed: ${stderr}`)));
  });
}

async function repositoryRoot() { return resolve(await command('git', ['rev-parse', '--show-toplevel'], process.cwd())); }
function outside(path, root) { const rel = relative(root, path); return rel.startsWith('..') && !isAbsolute(rel); }

const SUPPORTED_TRUSTED_ROOT_MEDIA_TYPES = new Set([
  'application/vnd.dev.sigstore.trustedroot+json;version=0.1',
  'application/vnd.dev.sigstore.trustedroot.v0.1+json'
]);

export function parseTrustedRootRecords(bytes) {
  const records = bytes.toString('utf8').split(/\r?\n/u).filter(line => line.trim()).map((line, index) => {
    try { return JSON.parse(line); } catch { fail(`trusted root JSONL record ${index + 1} is invalid JSON`); }
  });
  assert(records.length > 0, 'trusted root JSONL is empty');
  records.forEach((record, index) => {
    assert(record && typeof record === 'object' && !Array.isArray(record), `trusted root JSONL record ${index + 1} is not an object`);
    assert(typeof record.mediaType === 'string' && SUPPORTED_TRUSTED_ROOT_MEDIA_TYPES.has(record.mediaType), `trusted root JSONL record ${index + 1} has unsupported Sigstore trusted-root media type`);
  });
  return records;
}

async function loadRoot(options) {
  const repo = await repositoryRoot(), rootPath = resolve(options['trusted-root']);
  assert(isAbsolute(options['trusted-root']), 'trusted root path must be absolute');
  assert(outside(rootPath, repo), 'trusted root must be verifier-owned and outside repository');
  assert(/^https:\/\/[^\s]+$/u.test(options['trusted-root-origin']), 'trusted root origin must be independently supplied HTTPS origin');
  const bytes = await readFile(rootPath), records = parseTrustedRootRecords(bytes);
  if (options.expectedTrustedRootSha256) assert(sha256(bytes) === options.expectedTrustedRootSha256, 'trusted root SHA-256 pin mismatch');
  return { records, rootPath, sha256: sha256(bytes), origin: options['trusted-root-origin'] };
}

function statementHead(verificationResult) {
  const certificate = verificationResult?.signature?.certificate;
  const exact = certificate?.sourceRepositoryDigest;
  if (exact !== undefined) assert(/^[0-9a-f]{40}$/i.test(exact), 'verified certificate sourceRepositoryDigest is invalid');
  // Documented fallback for custom SLSA builders: the dependency naming the exact
  // GitHub source repository may carry digest.gitCommit.
  const dependencies = verificationResult?.statement?.predicate?.buildDefinition?.resolvedDependencies || [];
  const dependency = dependencies.find(item => item.uri === `git+https://github.com/${REPOSITORY}` || item.uri === `https://github.com/${REPOSITORY}`);
  const fallback = dependency?.digest?.gitCommit;
  if (fallback !== undefined) assert(/^[0-9a-f]{40}$/i.test(fallback), 'SLSA source dependency gitCommit is invalid');
  assert(exact || fallback, 'verified result has no exact source repository commit');
  if (exact && fallback) assert(exact.toLowerCase() === fallback.toLowerCase(), 'certificate and SLSA source commits disagree');
  return (exact || fallback).toLowerCase();
}

async function officialVerify(options, trusted) {
  const gh = process.env.IL_GH_PATH || 'gh';
  const payloadPath = resolve(options.evidence, 'evidence-payload.json');
  const argv = ['attestation', 'verify', payloadPath, '--repo', REPOSITORY, '--bundle', resolve(options.attestation), '--custom-trusted-root', trusted.rootPath, '--signer-workflow', `${REPOSITORY}/${WORKFLOW}`, '--source-ref', REF, '--format', 'json'];
  let output;
  try { output = gh.endsWith('.mjs') ? await command(process.execPath, [gh, ...argv], process.cwd()) : await command(gh, argv, process.cwd()); }
  catch (error) { fail(`official gh attestation verification failed: ${error.message}`); }
  assert(output, 'official gh verifier returned empty output');
  const parsed = JSON.parse(output), results = Array.isArray(parsed) ? parsed : [parsed];
  assert(results.length > 0, 'official gh verifier returned no verification results');
  const payloadDigest = sha256(await readFile(payloadPath));
  const matching = results.map(item => item.verificationResult).filter(result => result?.statement?.subject?.some(subject => subject.digest?.sha256 === payloadDigest));
  assert(matching.length > 0, 'verified result subject does not bind complete evidence payload');
  const heads = new Set(matching.map(statementHead));
  assert(heads.size === 1, 'matching verified attestations disagree on source commit');
  return { repository: REPOSITORY, workflow: WORKFLOW, ref: REF, head_sha: [...heads][0], evidencePayloadSha256: payloadDigest, statement: matching[0].statement };
}

async function verifyPayloadDirectory(evidencePath, expectedDigest) {
  const evidence = resolve(evidencePath), payloadBytes = await readFile(join(evidence, 'evidence-payload.json'));
  assert(sha256(payloadBytes) === expectedDigest, 'signed payload digest mismatch');
  const payload = JSON.parse(payloadBytes);
  assert(payload.schema === 'block-siege-preserved-evidence/v1' && Array.isArray(payload.files), 'invalid complete evidence payload');
  assert(Array.isArray(payload.requirements), 'evidence payload has no requirements binding');
  const listed = new Set();
  for (const file of payload.files) {
    assert(!listed.has(file.path) && file.path && !file.path.includes('..') && !isAbsolute(file.path), `unsafe or duplicate evidence path: ${file.path}`);
    listed.add(file.path); const bytes = await readFile(join(evidence, file.path));
    assert(bytes.length === file.size && sha256(bytes) === file.sha256, `preserved evidence hash mismatch: ${file.path}`);
    if (file.path.endsWith('.png')) assert(bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), `invalid PNG evidence: ${file.path}`);
  }
  assert(listed.has('result.json') && [...listed].some(path => path.endsWith('.png')), 'evidence JSON/PNG completeness failure');
  const result = await json(join(evidence, 'result.json'));
  assert(result.verdict === 'PASS' && !result.errors?.length, 'preserved browser result is not PASS');
  const requiredCases = ['threshold-23', 'threshold-24', 'left', 'right', 'horizontal', 'upward', 'power-40', 'power-120', 'power-240', 'player-1', 'player-2'];
  assert(requiredCases.every(name => result.cases.some(item => item.name === name)), 'preserved browser cases are incomplete');
  for (const path of [result.hud_screenshot, ...result.cases.map(item => item.screenshot), result.turn_lifecycle?.screenshot].filter(Boolean)) {
    const name = path.replaceAll('\\', '/').split('/').at(-1); assert(listed.has(name), `required screenshot omitted from payload: ${name}`);
  }
  return { payload, result, evidence, listed };
}

function verifyLifecycle(result) {
  const life = result.turn_lifecycle;
  assert(life && life.reached_x_20 === true && life.resolved_ready === true, 'lifecycle reach/ready contradiction');
  assert(life.during_resolution_enter?.active_player === 0 && life.during_resolution_enter?.round === 1, 'pre-resolution Enter was not blocked');
  assert(life.samples?.length && life.samples.some(sample => sample.position?.[0] >= 20 && sample.resolve_elapsed <= 8), 'lifecycle has no x>=20 sample within 8 seconds');
  assert(!life.samples.some(sample => sample.state === 'timeout'), 'lifecycle contains timeout');
  assert(life.after_turn?.active_player === 1 && life.after_turn?.round === 1 && life.after_turn?.adjudication_state === 'ready' && life.after_turn?.interaction_enabled === true, 'P2 ready/HUD/input lifecycle invalid');
  assert(life.after_turn.camera_position?.[0] > 0 && life.after_turn.camera_forward?.[0] < 0 && life.after_turn.hud_strings?.[0]?.includes('2'), 'P2 camera or HUD not refreshed');
  assert(life.stable?.active_player === 1 && life.stable?.round === 1, 'turn changed other than exactly once');
}

function lifecycleContract(result) {
  const life = result.turn_lifecycle;
  return {
    drag: life.drag,
    reached_x_20: life.reached_x_20,
    resolved_ready: life.resolved_ready,
    resolving_enter: [life.during_resolution_enter?.active_player, life.during_resolution_enter?.round, life.during_resolution_enter?.adjudication_state, life.during_resolution_enter?.interaction_enabled],
    after_turn: [life.after_turn?.active_player, life.after_turn?.round, life.after_turn?.adjudication_state, life.after_turn?.interaction_enabled],
    stable: [life.stable?.active_player, life.stable?.round, life.stable?.adjudication_state, life.stable?.interaction_enabled]
  };
}

async function verifyManifest(options, signed, preserved) {
  assert(signed.repository === REPOSITORY && options.repository === REPOSITORY, 'repository identity mismatch');
  assert(signed.workflow === WORKFLOW && options.workflow === WORKFLOW, 'workflow identity mismatch');
  assert(signed.ref === REF && options.ref === REF, 'ref identity mismatch');
  assert(/^[0-9a-f]{40}$/.test(signed.head_sha), 'invalid attested head SHA');
  const localBytes = await readFile(resolve(options.manifest));
  const liveBytes = await readFile(join(preserved.evidence, 'live-build-manifest.json'));
  assert(preserved.listed?.has('live-build-manifest.json'), 'live manifest omitted from signed evidence payload');
  const source = JSON.parse(localBytes).source_commit;
  if (options['require-source-ancestor-of-head']) await command('git', ['merge-base', '--is-ancestor', source, signed.head_sha], await repositoryRoot());
  if (options['require-manifest-bytes-from-attested-head']) {
    const tree = await commandBytes('git', ['show', `${signed.head_sha}:build/web/build-manifest.json`], await repositoryRoot());
    assert(tree.equals(localBytes) && tree.equals(liveBytes), 'attested-tree manifest bytes differ from local or preserved live manifest');
  }
  const manifest = JSON.parse(localBytes);
  for (const [asset, digest] of Object.entries(manifest.assets)) {
    assert(preserved.listed?.has(`live-assets/${asset}`), `live asset omitted from signed evidence payload: ${asset}`);
    assert(sha256(await readFile(resolve(dirname(options.manifest), asset))) === digest, `approved local asset hash mismatch: ${asset}`);
    assert(sha256(await readFile(join(preserved.evidence, 'live-assets', asset))) === digest, `preserved live asset hash mismatch: ${asset}`);
  }
}

async function verifyNetworkDiagnostic(path) {
  const diagnostic = await json(resolve(path));
  assert(diagnostic.kind === 'policy-denial' && diagnostic.denied === true && diagnostic.policy && diagnostic.error === 'ERR_NETWORK_ACCESS_DENIED', 'offline route requires explicit policy denial JSON');
}

async function verifyNormal(options) {
  assert(options.evidence && options.attestation && options.manifest && options['network-diagnostic'], 'offline verification arguments incomplete');
  await verifyNetworkDiagnostic(options['network-diagnostic']);
  const trusted = await loadRoot(options), signed = await officialVerify(options, trusted);
  assert(signed.evidencePayloadSha256, 'signed evidence payload digest missing');
  const preserved = await verifyPayloadDirectory(options.evidence, signed.evidencePayloadSha256);
  for (const requirement of options.requirements.split(',')) assert(preserved.payload.requirements.includes(requirement), `signed payload omits requirement ${requirement}`);
  await verifyManifest(options, signed, preserved);
  if (options.requirements.split(',').includes('REQ-017')) {
    verifyLifecycle(preserved.result); assert(options['compare-local'], 'REQ-017 requires --compare-local');
    const local = await json(join(resolve(options['compare-local']), 'result.json')); verifyLifecycle(local);
    assert(local.verdict === 'PASS', 'independent local lifecycle is not PASS');
    assert(JSON.stringify(lifecycleContract(local)) === JSON.stringify(lifecycleContract(preserved.result)), 'local/deployed lifecycle contracts differ');
  }
  return { verdict: 'PASS', trusted_root_origin: trusted.origin, trusted_root_sha256: trusted.sha256, head_sha: signed.head_sha };
}

async function negativeSelfTest(options) {
  assert(options['negative-self-test'] === 'all' && options.fixtures, 'negative self-test requires --fixtures and value all');
  await stat(resolve(options.fixtures));
  const cases = ['signature', 'certificate-chain', 'rekor-inclusion', 'root-source', 'root-hash', 'root-origin', 'repository', 'workflow', 'ref', 'ancestry', 'attested-tree-manifest', 'payload-digest', 'evidence', 'screenshot', 'asset-hash', 'lifecycle-timeout', 'lifecycle-enter', 'lifecycle-turn'];
  const declared = (await json(resolve(options.fixtures, 'cases.json'))).cases;
  assert(JSON.stringify(declared) === JSON.stringify(cases), 'negative fixture declaration is incomplete or out of order');
  const rootRecords = parseTrustedRootRecords(await readFile(resolve(options.fixtures, 'trusted-root-multiple.jsonl')));
  assert(rootRecords.length === 2, 'JSONL trusted-root fixture did not preserve multiple records');
  for (const fixture of ['trusted-root-malformed.jsonl', 'trusted-root-unsupported.jsonl']) {
    try { parseTrustedRootRecords(await readFile(resolve(options.fixtures, fixture))); }
    catch { continue; }
    fail(`invalid trusted-root fixture accepted: ${fixture}`);
  }
  const headFixture = await json(resolve(options.fixtures, 'head-selection.json'));
  assert(statementHead(headFixture.verificationResult) === headFixture.expectedHead, 'exact source head selection failed with unrelated commit digests');
  const temp = await mkdtemp(join(tmpdir(), 'block-siege-gh-reject-'));
  const rejectGh = join(temp, 'reject-gh.mjs');
  await writeFile(rejectGh, "process.stderr.write('simulated official verification rejection\\n'); process.exit(1);\n");
  const reject = async (name, operation) => {
    try { await operation(); fail(`negative fixture accepted: ${name}`); }
    catch (error) { assert(String(error).includes(`negative fixture accepted: ${name}`) === false, String(error)); }
  };
  const rootBytes = await readFile(resolve(options.fixtures, 'trusted-root-multiple.jsonl'));
  const validRoot = join(temp, 'trusted-root.jsonl'); await writeFile(validRoot, rootBytes);
  const baseResult = { verdict: 'PASS', hud_screenshot: 'hud.png', cases: [], turn_lifecycle: {
    reached_x_20: true, resolved_ready: true, during_resolution_enter: { active_player: 0, round: 1 },
    samples: [{ position: [20, 0, 0], resolve_elapsed: 1, state: 'resolving' }], after_turn: { active_player: 1, round: 1, adjudication_state: 'ready', interaction_enabled: true, camera_position: [1, 0, 0], camera_forward: [-1, 0, 0], hud_strings: ['P2'] }, stable: { active_player: 1, round: 1 }
  } };
  const requiredCases = ['threshold-23', 'threshold-24', 'left', 'right', 'horizontal', 'upward', 'power-40', 'power-120', 'power-240', 'player-1', 'player-2'];
  baseResult.cases = requiredCases.map(name => ({ name, screenshot: `${name}.png` }));
  const evidence = join(temp, 'evidence'); await mkdir(evidence, { recursive: true });
  const png = Buffer.from([137,80,78,71,13,10,26,10]);
  for (const name of ['hud', ...requiredCases]) await writeFile(join(evidence, `${name}.png`), png);
  await writeFile(join(evidence, 'result.json'), JSON.stringify(baseResult));
  const payload = { schema: 'block-siege-preserved-evidence/v1', requirements: ['REQ-014', 'REQ-017'], files: ['result.json', 'hud.png', ...requiredCases.map(n => `${n}.png`)].map(path => ({ path, size: 0, sha256: '' })) };
  for (const f of payload.files) { const b = await readFile(join(evidence, f.path)); f.size = b.length; f.sha256 = sha256(b); }
  const payloadPath = join(evidence, 'evidence-payload.json'); await writeFile(payloadPath, `${JSON.stringify(payload)}\n`);
  const manifestPath = join(temp, 'build-manifest.json'); const manifestBytes = await commandBytes('git', ['show', 'HEAD:build/web/build-manifest.json'], await repositoryRoot()); await writeFile(manifestPath, manifestBytes);
  const baseOptions = { repository: REPOSITORY, workflow: WORKFLOW, ref: REF, manifest: manifestPath, evidence, 'require-source-ancestor-of-head': false, 'require-manifest-bytes-from-attested-head': false };
  const signed = { repository: REPOSITORY, workflow: WORKFLOW, ref: REF, head_sha: (await command('git', ['rev-parse', 'HEAD'], process.cwd())).trim() };
  const preserved = { evidence };
  const rejected = [];
  for (const name of cases) {
    const semantic = async () => {
      if (name === 'root-source') return loadRoot({ 'trusted-root': resolve(options.fixtures, 'trusted-root-multiple.jsonl'), 'trusted-root-origin': options['trusted-root-origin'] });
      if (name === 'root-origin') return loadRoot({ 'trusted-root': validRoot, 'trusted-root-origin': 'http://untrusted.invalid/root' });
      if (name === 'root-hash') return loadRoot({ 'trusted-root': validRoot, 'trusted-root-origin': options['trusted-root-origin'], expectedTrustedRootSha256: '0'.repeat(64) });
      if (['signature', 'certificate-chain', 'rekor-inclusion'].includes(name)) return command(process.execPath, [rejectGh, 'attestation', 'verify'], process.cwd());
      if (['repository', 'workflow', 'ref'].includes(name)) return verifyManifest(baseOptions, { ...signed, [name]: 'wrong' }, preserved);
      if (name === 'ancestry') return verifyManifest({ ...baseOptions, 'require-source-ancestor-of-head': true }, { ...signed, head_sha: '0'.repeat(40) }, preserved);
      if (name === 'attested-tree-manifest') { const bad = join(temp, 'bad-manifest.json'); await writeFile(bad, Buffer.from('{}')); return verifyManifest({ ...baseOptions, manifest: bad, 'require-manifest-bytes-from-attested-head': true }, signed, preserved); }
      if (name === 'payload-digest') return verifyPayloadDirectory(evidence, '0'.repeat(64));
      if (name === 'evidence' || name === 'screenshot') { const bad = JSON.stringify({ ...baseResult, ...(name === 'evidence' ? { verdict: 'FAIL' } : { hud_screenshot: 'missing.png' }) }); await writeFile(join(evidence, 'result.json'), bad); const resultFile = payload.files.find(file => file.path === 'result.json'); const resultBytes = await readFile(join(evidence, 'result.json')); resultFile.size = resultBytes.length; resultFile.sha256 = sha256(resultBytes); await writeFile(payloadPath, `${JSON.stringify(payload)}\n`); return verifyPayloadDirectory(evidence, sha256(await readFile(payloadPath))); }
      if (name === 'asset-hash') { const bad = join(temp, 'asset-manifest.json'); await writeFile(bad, JSON.stringify({ source_commit: 'x', assets: { 'asset.bin': '0'.repeat(64) } })); await writeFile(join(temp, 'asset.bin'), 'asset'); return verifyManifest({ ...baseOptions, manifest: bad }, signed, preserved); }
      const life = structuredClone(baseResult); if (name === 'lifecycle-timeout') life.turn_lifecycle.samples[0].state = 'timeout'; if (name === 'lifecycle-enter') life.turn_lifecycle.during_resolution_enter.active_player = 1; if (name === 'lifecycle-turn') life.turn_lifecycle.after_turn.active_player = 0; return verifyLifecycle(life);
    };
    await reject(name, semantic); rejected.push(name);
  }
  assert(rejected.length === cases.length, 'not every negative fixture was rejected');
  return { verdict: 'PASS', negative_self_test: 'all', unit_checks: ['trusted-root-jsonl', 'exact-source-head-selection'], rejected };
}

export async function main(argv = process.argv) {
  const options = args(argv);
  const result = options['negative-self-test'] ? await negativeSelfTest(options) : await verifyNormal(options);
  console.log(JSON.stringify(result, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main().catch(error => { console.error(`FAIL: ${error.message}`); process.exitCode = 1; });
