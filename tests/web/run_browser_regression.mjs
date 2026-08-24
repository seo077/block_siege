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
  const child = spawn(chrome, [`--remote-debugging-port=${port}`, '--remote-allow-origins=*', `--user-data-dir=${profile}`, '--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--no-first-run', '--window-size=1280,720', 'about:blank'], { stdio: 'ignore' });
  let endpoint;
  for (let i = 0; i < 100 && !endpoint; i++) {
    try { endpoint = (await (await fetch(`http://127.0.0.1:${port}/json/version`)).json()).webSocketDebuggerUrl; } catch { await delay(100); }
  }
  assert(endpoint, 'Chrome DevTools endpoint did not start');
  const ws = new WebSocket(endpoint); await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = no; });
  const cdp = new CDP(ws); cdp.debugPort = port;
  return { cdp, child, profile, ws };
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
  await delay(2500);
  for (let i = 0; i < 40; i++) {
    try {
      if (await evaluate(client, undefined, `!!globalThis.__BLOCK_SIEGE_TEST__ && document.querySelector('canvas')?.width > 0`)) break;
    } catch {}
    if (i === 39) throw new Error('Godot canvas/test bridge did not become ready');
    await delay(100);
  }
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
    await delay(100);
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
  const approved = JSON.parse(await readFile(localPath, 'utf8'));
  assert(typeof approved.source_commit === 'string' && approved.source_commit.length > 0, 'manifest source_commit missing');
  assert(approved.assets && typeof approved.assets === 'object' && !Array.isArray(approved.assets), 'manifest assets missing');
  const localRoot = resolve(localPath, '..');
  const liveResponse = await fetch(new URL('build-manifest.json', baseUrl), { cache: 'no-store' });
  assert(liveResponse.ok, `live manifest fetch failed: HTTP ${liveResponse.status}`);
  const live = await liveResponse.json();
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
  return { source_commit: approved.source_commit, live_source_commit: live.source_commit, comparisons };
}

async function main() {
  const options = args(process.argv), evidence = resolve(options.evidence);
  await mkdir(evidence, { recursive: true });
  const server = options.serve ? await serve(options.serve, options['base-url']) : null;
  const chrome = await connectChrome();
  console.log('CDP connected');
  const result = { verdict: 'FAIL', base_url: options['base-url'], requirements: options.requirements.split(','), cases: [], errors: [], workflow_result: options['workflow-result'] || (options.serve ? 'local-not-applicable' : 'declared-success') };
  try {
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
    if (result.requirements.includes('REQ-014')) result.manifest = await manifestChecks(options.manifest, options['base-url']);
    result.verdict = 'PASS';
  } catch (error) { result.errors.push(error.stack || String(error)); process.exitCode = 1; }
  finally {
    await writeFile(join(evidence, 'result.json'), JSON.stringify(result, null, 2));
    chrome.ws.close(); chrome.child.kill(); spawn('taskkill', ['/pid', String(chrome.child.pid), '/t', '/f'], { stdio: 'ignore' }); server?.close();
  }
  console.log(`${result.verdict}: ${result.cases.length} browser cases; evidence ${join(evidence, 'result.json')}`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
