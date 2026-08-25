import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, mkdtemp, rm, stat } from 'node:fs/promises';
import { createReadStream, existsSync } from 'node:fs';
import { resolve, join, extname, relative, isAbsolute } from 'node:path';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';

const ORACLE = [
  '플레이어 1의 턴', '[1] 투석기  [2] 전차  |  마우스 드래그: 발사\n전차 선택 중 WASD: 이동  |  [Enter]: 턴 종료',
  '투석기 선택', '전차 선택', '드래그가 너무 짧습니다', '이 병기는 이번 턴에 이미 발사했습니다',
  '이 병기는 장전되지 않았습니다', '물리 판정 중…', '발사 판정 완료', '플레이어 %d 승리 — 요새 완파',
  '턴 전환', '플레이어 %d 판정승', '무승부', '라운드 %d/%d  |  플레이어 %d  |  %s',
  '예비 블럭 P1: %d  P2: %d  |  %s', '프로토타입 종료', '투석기', '전차',
];
const BAD_TEXT = /\uFFFD|(?:Ã.|Â.|â€¦|â€”|í.|ì.|ë.|ðŸ)/u;

function args(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i += 2) {
    if (!argv[i].startsWith('--') || argv[i + 1] === undefined) throw new Error(`Invalid argument ${argv[i]}`);
    out[argv[i].slice(2)] = argv[i + 1];
  }
  for (const key of ['base-url', 'requirements', 'evidence']) if (!out[key]) throw new Error(`Missing --${key}`);
  return out;
}

const delay = ms => new Promise(r => setTimeout(r, ms));
const assert = (condition, message) => { if (!condition) throw new Error(message); };

async function serve(directory, baseUrl) {
  const root = resolve(directory);
  const url = new URL(baseUrl);
  const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json; charset=utf-8' };
  const server = createServer(async (req, res) => {
    try {
      const decoded = decodeURIComponent(new URL(req.url, baseUrl).pathname);
      let file = resolve(root, `.${decoded}`);
      if (relative(root, file).startsWith('..') || isAbsolute(relative(root, file))) throw new Error('outside root');
      if ((await stat(file)).isDirectory()) file = join(file, 'index.html');
      res.setHeader('Content-Type', mime[extname(file)] || 'application/octet-stream');
      res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
      res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
      createReadStream(file).pipe(res);
    } catch { res.writeHead(404).end('not found'); }
  });
  await new Promise((ok, no) => server.once('error', no).listen(Number(url.port), url.hostname, ok));
  return server;
}

class CDP {
  constructor(ws, label = 'browser') {
    this.ws = ws; this.next = 1; this.pending = new Map(); this.listeners = [];
    ws.addEventListener('message', async e => {
      const payload = typeof e.data === 'string' ? e.data : e.data instanceof Blob ? await e.data.text() : Buffer.from(e.data).toString();
      const msg = JSON.parse(payload);
      for (const listener of this.listeners) listener(msg);
      if (!msg.id) return;
      const p = this.pending.get(msg.id); this.pending.delete(msg.id);
      if (!p) return;
      if (msg.error) p.reject(new Error(msg.error.message)); else p.resolve(msg.result);
    });
  }
  onMessage(listener) { this.listeners.push(listener); }
  send(method, params = {}, sessionId) {
    const id = this.next++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 60000);
      this.pending.set(id, { resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); } });
      this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
  }
}

class CDPSession {
  constructor(root, sessionId) {
    this.root = root; this.sessionId = sessionId; this.next = 1; this.pending = new Map();
    root.onMessage(event => {
      if (event.method !== 'Target.receivedMessageFromTarget' || event.params.sessionId !== sessionId) return;
      const msg = JSON.parse(event.params.message); if (!msg.id) return;
      const p = this.pending.get(msg.id); this.pending.delete(msg.id);
      if (msg.error) p.reject(new Error(msg.error.message)); else p.resolve(msg.result);
    });
  }
  send(method, params = {}) {
    const id = this.next++;
    const answer = new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
    return this.root.send('Target.sendMessageToTarget', { sessionId: this.sessionId, message: JSON.stringify({ id, method, params }) }).then(() => answer);
  }
}

async function connectChrome() {
  const chrome = ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'].find(existsSync);
  assert(chrome, 'Chrome or Edge not installed');
  const profile = await mkdtemp(join(tmpdir(), 'block-siege-cdp-'));
  const port = 9300 + Math.floor(Math.random() * 500);
  const child = spawn(chrome, [`--remote-debugging-port=${port}`, '--remote-allow-origins=*', `--user-data-dir=${profile}`, '--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-background-networking', '--disable-component-update', '--disable-default-apps', '--disable-extensions', '--disable-sync', '--metrics-recording-only', '--no-first-run', '--window-size=1280,720', 'about:blank'], { stdio: 'ignore' });
  let ws, cdp;
  try {
    let endpoint;
    for (let i = 0; i < 100 && !endpoint; i++) {
      try { endpoint = (await (await fetch(`http://127.0.0.1:${port}/json/version`)).json()).webSocketDebuggerUrl; } catch { await delay(100); }
    }
    assert(endpoint, 'Chrome DevTools endpoint did not start');
    ws = new WebSocket(endpoint); await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = no; });
    cdp = new CDP(ws); cdp.debugPort = port;
    return { cdp, child, profile, ws };
  } catch (error) {
    try { await closeChrome({ cdp, child, profile, ws }); }
    catch (cleanupError) { error.cause = cleanupError; }
    throw error;
  }
}

function waitForExit(child, timeoutMs) {
  if (child.exitCode !== null || child.signalCode !== null) return Promise.resolve(true);
  return new Promise(resolveExit => {
    const timer = setTimeout(() => { child.off('exit', onExit); resolveExit(false); }, timeoutMs);
    const onExit = () => { clearTimeout(timer); resolveExit(true); };
    child.once('exit', onExit);
  });
}

function runProcess(command, processArgs, timeoutMs = 20000) {
  return new Promise((resolveProcess, rejectProcess) => {
    const child = spawn(command, processArgs, { stdio: 'ignore' });
    const timer = setTimeout(() => {
      child.kill();
      rejectProcess(new Error(`${command} timed out after ${timeoutMs}ms`));
    }, timeoutMs);
    child.once('error', error => { clearTimeout(timer); rejectProcess(error); });
    child.once('exit', (code, signal) => { clearTimeout(timer); resolveProcess({ code, signal }); });
  });
}

async function closeChrome(chrome) {
  if (!chrome) return;
  const errors = [];
  let exited = chrome.child.exitCode !== null || chrome.child.signalCode !== null;
  if (!exited) {
    try {
      await Promise.race([
        chrome.cdp?.send('Browser.close'),
        delay(3000).then(() => { throw new Error('Browser.close timed out'); }),
      ]);
    } catch { /* The process-exit check below is authoritative. */ }
    exited = await waitForExit(chrome.child, 20000);
  }
  try { chrome.ws?.close(); } catch { /* The process-exit check below is authoritative. */ }
  let treeStopped = exited;
  if (process.platform === 'win32' && !exited) {
    try {
      const killed = await runProcess('taskkill', ['/pid', String(chrome.child.pid), '/t', '/f']);
      if (killed.code !== 0 && chrome.child.exitCode === null && chrome.child.signalCode === null) throw new Error(`taskkill exited ${killed.code ?? killed.signal}`);
      treeStopped = killed.code === 0;
    } catch (error) { errors.push(error); }
    exited = await waitForExit(chrome.child, 5000);
  } else if (process.platform !== 'win32' && !exited) {
    try { chrome.child.kill('SIGTERM'); } catch (error) { errors.push(error); }
    exited = await waitForExit(chrome.child, 5000);
    treeStopped = exited;
  }
  if (!exited) errors.push(new Error(`launched browser process ${chrome.child.pid} did not exit`));
  if (treeStopped || process.platform !== 'win32') {
    try { await rm(chrome.profile, { recursive: true, force: true, maxRetries: 12, retryDelay: 250 }); } catch (error) { errors.push(error); }
  } else {
    errors.push(new Error(`temporary profile retained because browser tree ${chrome.child.pid} did not stop cleanly: ${chrome.profile}`));
  }
  if (errors.length) throw new AggregateError(errors, 'browser cleanup failed');
}

function closeServer(server) {
  if (!server) return Promise.resolve();
  return new Promise((resolveClose, rejectClose) => {
    const forceTimer = setTimeout(() => server.closeAllConnections?.(), 3000);
    server.close(error => {
      clearTimeout(forceTimer);
      if (error) rejectClose(error); else resolveClose();
    });
  });
}

async function evaluate(cdp, sessionId, expression) {
  const result = await cdp.send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId);
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || 'browser evaluation failed');
  return result.result.value;
}

async function freshPage(cdp, baseUrl) {
  const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
  const client = { send: (method, params = {}) => cdp.send(method, params, sessionId) };
  await client.send('Page.navigate', { url: baseUrl });
  const startedAt = Date.now(), timeoutMs = 30000, pollMs = 250;
  let attempts = 0, lastProbe = null, lastEvaluationError = null;
  while (Date.now() - startedAt < timeoutMs) {
    attempts++;
    try {
      lastProbe = await Promise.race([evaluate(client, undefined, `(() => {
        const canvas = document.querySelector('canvas');
        return {
          ready: !!globalThis.__BLOCK_SIEGE_TEST__ && (canvas?.width ?? 0) > 0 && (canvas?.height ?? 0) > 0,
          url: location.href,
          document_ready_state: document.readyState,
          canvas_present: !!canvas,
          canvas_width: canvas?.width ?? 0,
          canvas_height: canvas?.height ?? 0,
          bridge_present: !!globalThis.__BLOCK_SIEGE_TEST__,
          bridge_type: typeof globalThis.__BLOCK_SIEGE_TEST__,
        };
      })()`), delay(2000).then(() => { throw new Error('readiness probe timed out after 2000ms'); })]);
      lastEvaluationError = null;
      if (lastProbe.ready) break;
    } catch (error) { lastEvaluationError = error.message || String(error); }
    await delay(pollMs);
  }
  const elapsedMs = Date.now() - startedAt;
  if (!lastProbe?.ready) throw new Error(`Godot canvas/test bridge did not become ready within ${timeoutMs}ms: ${JSON.stringify({ base_url: baseUrl, elapsed_ms: elapsedMs, attempts, last_probe: lastProbe, last_evaluation_error: lastEvaluationError })}`);
  await delay(1000);
  const rect = await evaluate(client, undefined, `(() => { const c=document.querySelector('canvas'),r=c.getBoundingClientRect(); return {x:r.x,y:r.y,w:r.width,h:r.height,cw:c.width,ch:c.height}; })()`);
  return { targetId, client, rect };
}

async function dragCase(cdp, baseUrl, evidence, name, dx, dy, player = 0) {
  console.log(`CASE ${name}`);
  const page = await freshPage(cdp, baseUrl);
  const { client, rect } = page;
  const x = rect.x + rect.w * .5, y = rect.y + rect.h * .65;
  await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, button: 'none', buttons: 0 });
  await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x + 100, y: y + 100, button: 'none', buttons: 0 });
  const calibration = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  const moves = calibration.pointer_events.filter(event => event.type === 'move').slice(-2);
  assert(moves.length === 2, `${name}: pointer calibration unavailable`);
  const scaleX = (moves[1].x - moves[0].x) / 100, scaleY = (moves[1].y - moves[0].y) / 100;
  const cssDx = (dx + Math.sign(dx) * .9) / scaleX, cssDy = (dy + Math.sign(dy) * .9) / scaleY;
  if (player === 1) {
    await client.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
    await client.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
    await delay(16);
  }
  await client.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x + cssDx, y: y + cssDy, button: 'left', buttons: 1 });
  await client.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x + cssDx, y: y + cssDy, button: 'left', buttons: 0, clickCount: 1 });
  const snapshot = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  const png = await client.send('Page.captureScreenshot', { format: 'png' });
  const screenshot = join(evidence, `${name}.png`); await writeFile(screenshot, Buffer.from(png.data, 'base64'));
  await cdp.send('Target.closeTarget', { targetId: page.targetId });
  return { name, drag: [dx, dy], screenshot, ...snapshot };
}

async function pressEnter(client) {
  await client.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
  await client.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
}

async function turnLifecycleCase(cdp, baseUrl, evidence) {
  console.log('CASE turn-lifecycle');
  const page = await freshPage(cdp, baseUrl), { client, rect } = page;
  const x = rect.x + rect.w * .5, y = rect.y + rect.h * .65;
  await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y, button: 'none', buttons: 0 });
  await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x + 100, y: y + 100, button: 'none', buttons: 0 });
  const calibration = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  const moves = calibration.pointer_events.filter(event => event.type === 'move').slice(-2);
  assert(moves.length === 2, 'turn-lifecycle: pointer calibration unavailable');
  const scaleY = (moves[1].y - moves[0].y) / 100;
  const cssDy = -240.9 / scaleY;
  await client.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y: y + cssDy, button: 'left', buttons: 1 });
  await client.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y: y + cssDy, button: 'left', buttons: 0, clickCount: 1 });
  const samples = [];
  let snapshot = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  assert(snapshot.adjudication_state === 'resolving' && snapshot.active_player === 0 && snapshot.round === 1, 'turn-lifecycle: real 240px drag did not begin P1 resolution');
  assert(snapshot.interaction_enabled === false, 'turn-lifecycle: input enabled while resolving');
  await pressEnter(client); await delay(100);
  const during = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  assert(during.active_player === 0 && during.round === 1, 'turn-lifecycle: Enter during resolution changed turn');
  const wallDeadline = Date.now() + 30000, physicsDeadline = 8.0;
  let reached = false, sawReady = false, lastPhysicsElapsed = snapshot.resolve_elapsed ?? 0;
  while (Date.now() < wallDeadline) {
    snapshot = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
    lastPhysicsElapsed = snapshot.resolve_elapsed ?? lastPhysicsElapsed;
    samples.push({ timestamp_ms: Date.now(), resolve_elapsed: snapshot.resolve_elapsed, position: snapshot.projectile_position, state: snapshot.adjudication_state, active_player: snapshot.active_player, round: snapshot.round, interaction_enabled: snapshot.interaction_enabled });
    if ((snapshot.projectile_position?.[0] >= 20 && lastPhysicsElapsed <= physicsDeadline) || snapshot.projectile_samples?.some(sample => sample.position?.[0] >= 20 && (sample.time ?? sample.resolve_elapsed ?? Infinity) <= physicsDeadline)) reached = true;
    assert(snapshot.adjudication_state !== 'timeout', `turn-lifecycle: resolution timed out: ${JSON.stringify({ projectile_position: snapshot.projectile_position, projectile_velocity: snapshot.projectile_velocity, projectile_contact_count: snapshot.projectile_contact_count, projectile_bottom_y: snapshot.projectile_bottom_y, non_quiet_tracked_bodies: snapshot.non_quiet_tracked_bodies })}`);
    if (snapshot.adjudication_state === 'ready') { sawReady = true; break; }
    assert(lastPhysicsElapsed <= physicsDeadline, `turn-lifecycle: resolving did not return to ready within ${physicsDeadline.toFixed(1)}s physics elapsed: ${JSON.stringify({ resolve_elapsed: lastPhysicsElapsed, last_snapshot: snapshot })}`);
	await delay(16);
  }
  assert(sawReady, `turn-lifecycle: wall cap reached before ready: ${JSON.stringify({ wall_cap_ms: 30000, resolve_elapsed: lastPhysicsElapsed, last_snapshot: snapshot })}`);
  assert(reached, 'turn-lifecycle: projectile did not reach x >= 20 within 8.0s');
  assert(lastPhysicsElapsed <= physicsDeadline && snapshot.active_player === 0 && snapshot.round === 1 && snapshot.interaction_enabled, 'turn-lifecycle: resolving did not return to ready P1 input within 8.0s physics elapsed');
  const p1Camera = snapshot.camera_position;
  await pressEnter(client); await delay(150);
  const after = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  assert(after.active_player === 1 && after.round === 1 && after.adjudication_state === 'ready' && after.interaction_enabled, 'turn-lifecycle: one Enter did not enable ready P2 in round 1');
  assert(p1Camera[0] < 0 && after.camera_position[0] > 0 && after.camera_forward[0] < 0, 'turn-lifecycle: P2 camera did not refresh orientation');
  assert(after.hud_strings[0].includes('2'), 'turn-lifecycle: P2 HUD did not refresh');
  await delay(150);
  const stable = await evaluate(client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
  assert(stable.active_player === 1 && stable.round === 1, 'turn-lifecycle: turn changed more than once');
  assert(after.pointer_events.some(e => e.type === 'press') && after.pointer_events.some(e => e.type === 'move') && after.pointer_events.some(e => e.type === 'release'), 'turn-lifecycle: missing real canvas pointer events');
  const png = await client.send('Page.captureScreenshot', { format: 'png' });
  const screenshot = join(evidence, 'turn-lifecycle.png'); await writeFile(screenshot, Buffer.from(png.data, 'base64'));
  await cdp.send('Target.closeTarget', { targetId: page.targetId });
  return { name: 'turn-lifecycle', drag: [0, -240], during_resolution_enter: during, samples, reached_x_20: reached, resolved_ready: sawReady, after_turn: after, stable, screenshot };
}

async function utf8Checks(serveDir, runtime) {
  assert(JSON.stringify(runtime.approved_korean_strings) === JSON.stringify(ORACLE), 'approved Korean oracle mismatch');
  assert(Array.isArray(runtime.missing_glyph_codepoints) && runtime.missing_glyph_codepoints.length === 0, `active HUD font missing glyphs: ${runtime.missing_glyph_codepoints}`);
  assert(runtime.hud_strings.length >= 5, 'runtime HUD fields missing');
  const hud = runtime.hud_strings.join('\n');
  assert(!BAD_TEXT.test(hud), 'runtime HUD contains mojibake/replacement characters');
  assert(runtime.hud_strings[0] === '라운드 1/20  |  플레이어 1  |  투석기', 'initial status HUD mismatch');
  assert(runtime.hud_strings[1] === ORACLE[1], 'initial hint HUD mismatch');
  assert(runtime.hud_strings[2].startsWith('예비 블럭 P1: 87  P2: 87  |  플레이어 1의 턴'), 'initial debug HUD mismatch');
  assert((() => { try { assert('틀린 문자열' === ORACLE[0], 'negative self-test'); return false; } catch { return true; } })(), 'mismatch detector negative self-test failed');
  if (serveDir) {
    const source = await readFile(resolve('scripts/main.gd'), 'utf8');
    assert(!BAD_TEXT.test(source), 'source contains mojibake/replacement characters');
    for (const s of ORACLE) assert(source.includes(s.replaceAll('\n', '\\n')), `source missing oracle string: ${s}`);
    for (const asset of ['index.html', 'index.js']) {
      const bytes = await readFile(resolve(serveDir, asset));
      const decoded = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
      assert(!BAD_TEXT.test(decoded), `Web export ${asset} contains mojibake/replacement characters`);
    }
  }
}

async function sha256(bytes) { return createHash('sha256').update(bytes).digest('hex'); }

async function manifestChecks(manifestPath, baseUrl) {
  assert(manifestPath, 'REQ-014 requires --manifest');
  const localPath = resolve(manifestPath);
  const approvedBytes = await readFile(localPath);
  const approved = JSON.parse(approvedBytes.toString('utf8'));
  assert(typeof approved.source_commit === 'string' && approved.source_commit.length > 0, 'manifest source_commit missing');
  assert(approved.assets && typeof approved.assets === 'object' && !Array.isArray(approved.assets), 'manifest assets missing');
  const localRoot = resolve(localPath, '..');
  const liveResponse = await fetch(new URL('build-manifest.json', baseUrl), { cache: 'no-store' });
  assert(liveResponse.ok, `live manifest fetch failed: HTTP ${liveResponse.status}`);
  const liveBytes = Buffer.from(await liveResponse.arrayBuffer());
  const live = JSON.parse(liveBytes.toString('utf8'));
  assert(live.source_commit === approved.source_commit, `live source_commit mismatch: ${live.source_commit}`);
  assert(JSON.stringify(live.assets) === JSON.stringify(approved.assets), 'live manifest asset list/hashes differ from approved manifest');
  const comparisons = [];
  for (const [asset, expected] of Object.entries(approved.assets)) {
    assert(!asset.startsWith('/') && !asset.includes('..') && asset !== 'build-manifest.json', `unsafe manifest asset: ${asset}`);
    assert(/^[0-9a-f]{64}$/.test(expected), `invalid SHA-256 for ${asset}`);
    const localHash = await sha256(await readFile(resolve(localRoot, asset)));
    const response = await fetch(new URL(asset, baseUrl), { cache: 'no-store' });
    assert(response.ok, `live asset fetch failed for ${asset}: HTTP ${response.status}`);
    const liveHash = await sha256(Buffer.from(await response.arrayBuffer()));
    comparisons.push({ path: asset, expected_sha256: expected, local_sha256: localHash, live_sha256: liveHash, match: expected === localHash && expected === liveHash });
    assert(expected === localHash, `approved local asset hash mismatch: ${asset}`);
    assert(expected === liveHash, `live asset hash mismatch: ${asset}`);
  }
  return {
    evidence: { source_commit: approved.source_commit, live_source_commit: live.source_commit, comparisons },
    approvedBytes,
    liveBytes,
  };
}

async function verifyDeploymentWorkflow(approvedBytes, liveBytes) {
  const api = 'https://api.github.com/repos/seo077/block_siege/actions/workflows/pages.yml/runs';
  const headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'block-siege-regression-verifier', 'X-GitHub-Api-Version': '2022-11-28' };
  const successfulRuns = [];
  for (let page = 1; ; page++) {
    const response = await fetch(`${api}?branch=master&status=completed&per_page=100&page=${page}`, { headers, cache: 'no-store' });
    assert(response.ok, `GitHub Actions API fetch failed: HTTP ${response.status}`);
    const payload = await response.json();
    assert(Array.isArray(payload.workflow_runs), 'GitHub Actions API returned invalid workflow_runs');
    successfulRuns.push(...payload.workflow_runs.filter(run => run.head_branch === 'master' && run.status === 'completed' && run.conclusion === 'success'));
    if (payload.workflow_runs.length < 100) break;
  }
  assert(successfulRuns.length > 0, 'no completed successful pages.yml run found for master');
  const mismatches = [];
  for (const run of successfulRuns) {
    assert(typeof run.head_sha === 'string' && /^[0-9a-f]{40}$/.test(run.head_sha), `workflow run ${run.id} has invalid head_sha`);
    const rawUrl = `https://raw.githubusercontent.com/seo077/block_siege/${run.head_sha}/build/web/build-manifest.json`;
    const response = await fetch(rawUrl, { cache: 'no-store' });
    if (!response.ok) {
      mismatches.push({ workflow_id: run.workflow_id, run_id: run.id, head_sha: run.head_sha, raw_manifest_http_status: response.status });
      continue;
    }
    const rawBytes = Buffer.from(await response.arrayBuffer());
    const approvedMatch = rawBytes.equals(approvedBytes);
    const liveMatch = rawBytes.equals(liveBytes);
    if (!approvedMatch || !liveMatch) {
      mismatches.push({ workflow_id: run.workflow_id, run_id: run.id, head_sha: run.head_sha, approved_match: approvedMatch, live_match: liveMatch });
      continue;
    }
    const manifestSha256 = await sha256(rawBytes);
    return {
      workflow_id: run.workflow_id,
      run_id: run.id,
      head_sha: run.head_sha,
      status: run.status,
      conclusion: run.conclusion,
      html_url: run.html_url,
      comparison_binding: {
        raw_manifest_url: rawUrl,
        approved_manifest_sha256: await sha256(approvedBytes),
        live_manifest_sha256: await sha256(liveBytes),
        workflow_manifest_sha256: manifestSha256,
        exact_byte_match: true,
      },
    };
  }
  throw new Error(`no completed successful pages.yml master run has a raw manifest exactly matching approved and live manifests: ${JSON.stringify(mismatches)}`);
}

async function main() {
  const options = args(process.argv), evidence = resolve(options.evidence);
  await mkdir(evidence, { recursive: true });
  let server = null, chrome = null, primaryError = null;
  const result = { verdict: 'FAIL', base_url: options['base-url'], requirements: options.requirements.split(','), cases: [], errors: [], workflow_result: options.serve ? 'local-not-applicable' : null };
  try {
    server = options.serve ? await serve(options.serve, options['base-url']) : null;
    chrome = await connectChrome();
    console.log('CDP connected');
    console.log('CASE hud');
    const initial = await freshPage(chrome.cdp, options['base-url']);
    const runtime = await evaluate(initial.client, undefined, `globalThis.__BLOCK_SIEGE_TEST__.snapshot()`);
    await utf8Checks(options.serve, runtime); result.runtime_hud = runtime.hud_strings; result.approved_korean_strings = runtime.approved_korean_strings;
    const png = await initial.client.send('Page.captureScreenshot', { format: 'png' });
    result.hud_screenshot = join(evidence, 'hud.png'); await writeFile(result.hud_screenshot, Buffer.from(png.data, 'base64'));
    await chrome.cdp.send('Target.closeTarget', { targetId: initial.targetId });
    const cases = [];
    for (const spec of [['threshold-23',23,0,0],['threshold-24',24,0,0],['left',-80,0,0],['right',80,0,0],['horizontal',0,80,0],['upward',0,-80,0],['power-40',40,0,0],['power-120',120,0,0],['power-240',240,0,0],['player-1',80,0,0],['player-2',80,0,1]]) cases.push(await dragCase(chrome.cdp, options['base-url'], evidence, ...spec));
    result.cases = cases; const by = Object.fromEntries(cases.map(c => [c.name, c]));
    assert(by['threshold-23'].shot_count === 0 && by['threshold-23'].adjudication_state === 'ready', '23px drag fired');
    assert(by['threshold-24'].shot_count === 1 && by['threshold-24'].adjudication_state === 'resolving', '24px drag did not fire exactly once/resolve');
    for (const c of cases) { assert(c.pointer_events.some(e => e.type === 'press') && c.pointer_events.some(e => e.type === 'move') && c.pointer_events.some(e => e.type === 'release'), `${c.name}: missing actual pointer events`); }
    assert(by.left.normalized_direction[2] < 0 && by.right.normalized_direction[2] > 0, 'left/right lateral signs incorrect');
    assert(by.upward.normalized_direction[1] > by.horizontal.normalized_direction[1], 'upward drag did not increase elevation');
    assert(by['power-40'].impulse_magnitude < by['power-120'].impulse_magnitude && by['power-120'].impulse_magnitude < by['power-240'].impulse_magnitude, 'impulse not strictly monotonic');
    assert(by['player-1'].active_player === 0 && by['player-1'].normalized_direction[0] > 0, 'player 1 not opponent-facing');
    assert(by['player-2'].active_player === 1 && by['player-2'].normalized_direction[0] < 0, 'player 2 not opponent-facing');
    assert(Math.sign(by['player-1'].normalized_direction[2]) === -Math.sign(by['player-2'].normalized_direction[2]), 'camera-relative lateral semantics differ');
    for (const c of cases.filter(c => c.shot_count)) { assert(c.shot_id >= 0 && c.initial_velocity.length === 3 && c.impulse_magnitude > 0 && c.normalized_direction.length === 3, `${c.name}: incomplete launch telemetry`); }
    if (result.requirements.includes('REQ-017')) result.turn_lifecycle = await turnLifecycleCase(chrome.cdp, options['base-url'], evidence);
    if (result.requirements.includes('REQ-014')) {
      const checkedManifest = await manifestChecks(options.manifest, options['base-url']);
      result.manifest = checkedManifest.evidence;
      if (!options.serve) result.workflow_result = await verifyDeploymentWorkflow(checkedManifest.approvedBytes, checkedManifest.liveBytes);
    }
    result.verdict = 'PASS';
  } catch (error) { primaryError = error; result.errors.push(error.stack || String(error)); process.exitCode = 1; }
  finally {
    for (const cleanup of [() => closeChrome(chrome), () => closeServer(server)]) {
      try { await cleanup(); }
      catch (error) {
        result.errors.push(error.stack || String(error));
        process.exitCode = 1;
        if (!primaryError) primaryError = error;
      }
    }
    await writeFile(join(evidence, 'result.json'), JSON.stringify(result, null, 2));
  }
  console.log(`${result.verdict}: ${result.cases.length} browser cases; evidence ${join(evidence, 'result.json')}`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
