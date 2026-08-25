import { readFile, readdir, mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { resolve, relative, dirname, join, extname } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';

const LOCAL_REF = /(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)/gu;
const FORBIDDEN = [
  [/\bextends\s+(?:Node|Control|CanvasItem|Node[23]D|RigidBody3D|CharacterBody3D|Area[23]D)\b/u, 'scene-node inheritance'],
  [/\b(?:Input|InputEvent|DisplayServer|RenderingServer)\b/u, 'UI/input adapter dependency'],
  [/(?:players\s*\[\s*0\s*\][\s\S]*players\s*\[\s*1\s*\]|players\s*\[\s*1\s*\][\s\S]*players\s*\[\s*0\s*\]|for\s+\w+\s+in\s*\[\s*0\s*,\s*1\s*\])/u, 'fixed two-player pair'],
];

async function filesUnder(directory) {
  const output = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) output.push(...await filesUnder(path));
    else if (entry.isFile() && ['.gd', '.mjs', '.js'].includes(extname(path))) output.push(path);
  }
  return output;
}

async function autoloadRefs(projectRoot) {
  let project;
  try { project = await readFile(join(projectRoot, 'project.godot'), 'utf8'); } catch { return []; }
  const section = project.match(/\[autoload\]([\s\S]*?)(?=\n\[|$)/u)?.[1] ?? '';
  return [...section.matchAll(/^[^;\n=]+\s*=\s*["']\*?res:\/\/([^"']+)["']/gmu)].map(match => match[1]);
}

export async function verifyCoreStateBoundary({ projectRoot = '.', root = 'scripts/core' } = {}) {
  const project = resolve(projectRoot), start = resolve(project, root);
  const queue = (await filesUnder(start)).sort();
  const autoloads = await autoloadRefs(project);
  const visited = new Set(), edges = [], violations = [];
  while (queue.length) {
    const file = resolve(queue.shift());
    if (visited.has(file)) continue;
    visited.add(file);
    const source = await readFile(file, 'utf8');
    const refs = [...source.matchAll(LOCAL_REF)].map(match => match[1]);
    const identifiers = new Set([...source.matchAll(/\b[A-Z][A-Za-z0-9_]*\b/gu)].map(match => match[0]));
    for (const ref of autoloads) {
      const name = ref.split('/').at(-1).replace(/\.[^.]+$/u, '');
      const pascal = name.split('_').map(part => part[0]?.toUpperCase() + part.slice(1)).join('');
      if (identifiers.has(pascal)) refs.push(ref);
    }
    for (const ref of [...new Set(refs)].sort()) {
      const target = resolve(project, ref);
      edges.push([relative(project, file).replaceAll('\\', '/'), relative(project, target).replaceAll('\\', '/')]);
      if (target.startsWith(project) && ['.gd', '.mjs', '.js'].includes(extname(target))) queue.push(target);
    }
    for (const [pattern, reason] of FORBIDDEN) if (pattern.test(source)) violations.push(`${relative(project, file)}: ${reason}`);
  }
  const report = { visited: [...visited].map(file => relative(project, file).replaceAll('\\', '/')).sort(), edges: edges.sort(), violations };
  if (violations.length) throw Object.assign(new Error(`core boundary violations:\n${violations.join('\n')}`), { report });
  return report;
}

async function negativeSelfTest(name) {
  if (name !== 'indirect-helper-autoload') throw new Error(`unknown negative self-test: ${name}`);
  const fixture = await mkdtemp(join(tmpdir(), 'block-siege-boundary-'));
  try {
    await mkdir(join(fixture, 'scripts/core'), { recursive: true });
    await mkdir(join(fixture, 'scripts/helpers'), { recursive: true });
    await writeFile(join(fixture, 'project.godot'), '[autoload]\nBadState="*res://scripts/helpers/bad_state.gd"\n');
    await writeFile(join(fixture, 'scripts/core/model.gd'), 'extends RefCounted\nconst Helper = preload("res://scripts/helpers/helper.gd")\n');
    await writeFile(join(fixture, 'scripts/helpers/helper.gd'), 'extends RefCounted\nfunc read(): return BadState.value\n');
    await writeFile(join(fixture, 'scripts/helpers/bad_state.gd'), 'extends Node\nvar value = Input.is_key_pressed(KEY_A)\n');
    try { await verifyCoreStateBoundary({ projectRoot: fixture, root: 'scripts/core' }); }
    catch (error) { if (error.report?.violations.length) return; throw error; }
    throw new Error('indirect helper/autoload corruption was accepted');
  } finally { await rm(fixture, { recursive: true, force: true }); }
}

export async function main() {
  const argv = process.argv.slice(2), option = key => { const index = argv.indexOf(key); return index < 0 ? undefined : argv[index + 1]; };
  if (!argv.includes('--transitive')) throw new Error('--transitive is required');
  const report = await verifyCoreStateBoundary({ root: option('--root') ?? 'scripts/core' });
  console.log(JSON.stringify(report, null, 2));
  if (option('--negative-self-test')) await negativeSelfTest(option('--negative-self-test'));
  console.log('PASS core state boundary');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main().catch(error => { console.error(error.message); if (error.report) console.error(JSON.stringify(error.report, null, 2)); process.exitCode = 1; });
