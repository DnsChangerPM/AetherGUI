#!/usr/bin/env node
// Stamps one application version into every file that carries it.
//
//   node scripts/set-version.mjs 2.2.0                    write 2.2.0 everywhere
//   node scripts/set-version.mjs 2.2.0 --version-code 31  ...and pin the Android versionCode
//   node scripts/set-version.mjs --check                  every stamp agrees, or exit 1
//   node scripts/set-version.mjs --print                  print the committed version
//
// The release workflow calls this from the "Resolve the application version" step, before
// `npm ci`, so a manually dispatched run can build a version this commit does not mention
// yet. It has to run that early because the version is read by npm ci (package.json), by
// `cargo test --locked` (Cargo.toml must agree with Cargo.lock), and by Gradle
// (android/app/build.gradle versionName), and because the Windows bundles are named
// Aethon_<version>_x64-setup.exe from src-tauri/tauri.conf.json.
//
// Every replacement below is anchored to the text around the version, never to the version
// string itself, and every file is re-read and verified after its edit. A global
// find-and-replace of the current version would corrupt this repository in at least three
// places that already exist:
//   - AETHON_SBOM.json lists the crates `derive_more` 2.1.1 and `derive_more-impl` 2.1.1
//   - VpnConnectionController.java documents what "v2.1.1 stored" - past behaviour, not a stamp
//   - src-tauri/src/update.rs unit tests pass "2.1.1" in as data to a naming function
//
// Deliberately not stamped: README.md and AETHON_SBOM.*. Both are hand-written records of a
// specific release - notes, digests, sizes, the commit they were taken at - so rewriting the
// version string in them would make them claim to describe a build they do not. The workflow
// emits a warning when a dispatched version leaves them behind.
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

// Three numeric components, no prefix, no pre-release suffix. Tauri, Cargo and Gradle all
// accept this, and the release assets are named Aethon-VPN-v<version>-<platform>, so anything
// with a '+' or a fourth component would end up in a URL and a filename.
export const VERSION_PATTERN = /^\d+\.\d+\.\d+$/;

export const read = rel => readFile(join(repoRoot, rel), 'utf8');

// Git tags in this repository are v-prefixed and the release workflow passes one straight
// through, so a leading "v" is accepted and dropped here instead of at every call site.
// Anything else is refused before a single file is read.
export function normalizeVersion(raw) {
  const value = String(raw ?? '').trim().replace(/^v/i, '');
  if (!VERSION_PATTERN.test(value)) {
    throw new Error(`'${raw}' is not a version this project can build. Use three numeric components, e.g. 2.2.0.`);
  }
  return value;
}

const found = (text, regex) => [...text.matchAll(regex)].map(match => match[1]);

// Each target reports the version(s) it currently carries, so `--check` can prove the whole
// tree agrees, and applies a new one. `current` returns an array because several files carry
// the version more than once and a half-applied edit is the failure this guards against.
export const targets = [
  {
    file: 'src-tauri/tauri.conf.json',
    // The only top-level "version" key; the file has no other key by that name.
    current: text => found(text, /"version":\s*"([^"]+)"/g).slice(0, 1),
    update: (text, version) => text.replace(/("version":\s*")([^"]+)(")/, `$1${version}$3`),
  },
  {
    file: 'src-tauri/Cargo.toml',
    // Line-start `version = "..."` is the [package] version. The dependency lines that also
    // mention a version are inline (`serde = { version = "1", ... }`) and do not start a line.
    current: text => found(text, /^version = "([^"]+)"$/gm).slice(0, 1),
    update: (text, version) => text.replace(/^version = "[^"]+"$/m, `version = "${version}"`),
  },
  {
    file: 'src-tauri/Cargo.lock',
    // Only the aether-gui entry. `cargo test --locked` fails if this disagrees with Cargo.toml.
    current: text => found(text, /\[\[package\]\]\r?\nname = "aether-gui"\r?\nversion = "([^"]+)"/g),
    update: (text, version) =>
      text.replace(/(\[\[package\]\]\r?\nname = "aether-gui"\r?\nversion = ")[^"]+(")/, `$1${version}$2`),
  },
  {
    file: 'package.json',
    current: text => found(text, /"version":\s*"([^"]+)"/g).slice(0, 1),
    update: (text, version) => text.replace(/("version":\s*")([^"]+)(")/, `$1${version}$3`),
  },
  {
    file: 'package-lock.json',
    // The root version and packages[""].version are the first two "version" keys in the file;
    // every later one belongs to a dependency and must not be touched. Rewriting this file as
    // JSON would reformat all of it, so the two are replaced positionally instead.
    current: text => found(text, /"version":\s*"([^"]+)"/g).slice(0, 2),
    update: (text, version) => {
      let seen = 0;
      return text.replace(/("version":\s*")([^"]+)(")/g, (match, before, value, after) =>
        ++seen <= 2 ? `${before}${version}${after}` : match);
    },
  },
  {
    file: 'android/app/build.gradle',
    current: text => found(text, /versionName '([^']+)'/g),
    update: (text, version, context) =>
      text
        .replace(/versionName '[^']*'/, `versionName '${version}'`)
        .replace(/versionCode \d+/, `versionCode ${context.versionCode}`),
  },
  {
    file: 'android/app/src/main/res/values/strings.xml',
    current: text => found(text, /<string name="app_version"[^>]*>v([^<]+)<\/string>/g),
    update: (text, version) =>
      text.replace(/(<string name="app_version"[^>]*>v)[^<]+(<\/string>)/, `$1${version}$2`),
  },
  {
    file: 'src/index.html',
    // The drawer footer and the About hero show "v<version>"; the Updates row shows it bare.
    current: text => [
      ...found(text, /<small>v([0-9][0-9.]*)<\/small>/g),
      ...found(text, /<strong id="currentVersion">([0-9][0-9.]*)<\/strong>/g),
    ],
    update: (text, version) =>
      text
        .replace(/(<small>v)[0-9][0-9.]*(<\/small>)/g, `$1${version}$2`)
        .replace(/(<strong id="currentVersion">)[0-9][0-9.]*(<\/strong>)/g, `$1${version}$2`),
  },
  {
    file: 'src/app.js',
    // Both are fallbacks for $('currentVersion'); the backend value wins when it answers.
    current: text => found(text, /\$\('currentVersion'\)\.textContent=(?:info\.currentVersion\|\|)?'([0-9][0-9.]*)'/g),
    update: (text, version) =>
      text.replace(
        /(\$\('currentVersion'\)\.textContent=(?:info\.currentVersion\|\|)?')[0-9][0-9.]*(')/g,
        `$1${version}$2`),
  },
  {
    file: 'src-tauri/src/lib.rs',
    // The Cloudflare trace request identifies the client by version; a stale one sends the
    // wrong version to every diagnostic lookup.
    current: text => found(text, /User-Agent: Aethon\/([0-9][0-9.]*)/g),
    update: (text, version) => text.replace(/(User-Agent: Aethon\/)[0-9][0-9.]*/, `$1${version}`),
  },
  {
    file: 'scripts/package-release.ps1',
    // Defaults only - the workflow always passes -Version - but a stale default means a local
    // `npm run package:release` renames artifacts after the previous version. Both parameters
    // are reported so neither can drift.
    current: text => {
      const match = /\$Version = "([^"]+)", \[string\]\$AndroidVersion = "([^"]+)"/.exec(text);
      return match ? [match[1], match[2]] : [];
    },
    update: (text, version) =>
      text.replace(
        /(\$Version = ")[^"]+(", \[string\]\$AndroidVersion = ")[^"]+(")/,
        `$1${version}$2${version}$3`),
  },
  {
    file: 'scripts/package-windows81.ps1',
    current: text => found(text, /\[string\]\$Version = "([^"]+)"/g),
    update: (text, version) => text.replace(/(\[string\]\$Version = ")[^"]+(")/, `$1${version}$2`),
  },
];

const GRADLE = 'android/app/build.gradle';

export async function readCanonicalVersion() {
  const config = JSON.parse(await read('src-tauri/tauri.conf.json'));
  return config.version;
}

export async function readAndroidVersionCode() {
  const text = await read(GRADLE);
  const match = /versionCode (\d+)/.exec(text);
  if (!match) throw new Error(`${GRADLE} does not declare a versionCode.`);
  return Number(match[1]);
}

// Every stamp, as the repository stands. Returns the canonical version plus any file that
// disagrees with it, so a half-finished manual bump is caught before a build is cut.
export async function checkVersions() {
  const canonical = await readCanonicalVersion();
  const mismatches = [];
  for (const target of targets) {
    const reported = target.current(await read(target.file));
    if (reported.length === 0) {
      mismatches.push({ file: target.file, expected: canonical, found: 'no version stamp found' });
      continue;
    }
    for (const value of reported) {
      if (value !== canonical) mismatches.push({ file: target.file, expected: canonical, found: value });
    }
  }
  return { canonical, mismatches };
}

// Writes `version` into every target. Nothing is written until every file has been edited and
// verified in memory, so a pattern that stops matching fails the run instead of leaving the
// tree stamped in some places and not others.
export async function applyVersion(version, options = {}) {
  const value = normalizeVersion(version);
  const canonical = await readCanonicalVersion();
  const committedCode = await readAndroidVersionCode();
  // Play rejects an upload whose versionCode does not increase, and a dispatched version is
  // never committed, so the code is bumped by one rather than derived from the version: two
  // dispatches of different versions from one commit would otherwise collide on the same code.
  const versionCode = Number.isInteger(options.versionCode)
    ? options.versionCode
    : value === canonical
      ? committedCode
      : committedCode + 1;
  if (!Number.isInteger(versionCode) || versionCode <= 0) {
    throw new Error(`Refusing to write versionCode '${versionCode}'; it must be a positive integer.`);
  }

  const changes = [];
  const pending = [];
  for (const target of targets) {
    const before = await read(target.file);
    const after = target.update(before, value, { versionCode });
    const reported = target.current(after);
    if (reported.length === 0 || reported.some(entry => entry !== value)) {
      throw new Error(
        `${target.file} did not end up stamped as ${value} (found ${reported.join(', ') || 'nothing'}). ` +
        'The version stamp in that file has probably moved; fix scripts/set-version.mjs rather than editing the file by hand.');
    }
    if (after !== before) {
      pending.push([target.file, after]);
      changes.push(target.file);
    }
  }
  for (const [file, contents] of pending) await writeFile(join(repoRoot, file), contents);
  return { version: value, previous: canonical, versionCode, previousVersionCode: committedCode, changes };
}

function printUsage() {
  process.stderr.write(
    'usage: node scripts/set-version.mjs <version> [--version-code <code>]\n' +
    '       node scripts/set-version.mjs --check\n' +
    '       node scripts/set-version.mjs --print\n');
}

async function main(argv) {
  const positional = [];
  let mode = 'apply';
  let versionCode;
  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    if (arg === '--check' || arg === '--print') {
      mode = arg.slice(2);
    } else if (arg === '--version-code' || arg.startsWith('--version-code=')) {
      const supplied = arg.includes('=') ? arg.slice('--version-code='.length) : argv[++index];
      versionCode = Number(supplied);
      if (!Number.isInteger(versionCode)) {
        process.stderr.write(`'${supplied}' is not an integer versionCode.\n`);
        return 2;
      }
    } else if (arg.startsWith('--')) {
      printUsage();
      return 2;
    } else {
      positional.push(arg);
    }
  }

  if (mode === 'print') {
    process.stdout.write(`${await readCanonicalVersion()}\n`);
    return 0;
  }
  if (mode === 'check') {
    if (positional.length > 0) {
      printUsage();
      return 2;
    }
    const { canonical, mismatches } = await checkVersions();
    if (mismatches.length > 0) {
      process.stderr.write(`Application version is ${canonical}, but these files say otherwise:\n`);
      for (const mismatch of mismatches) {
        process.stderr.write(`  ${mismatch.file}: ${mismatch.found}\n`);
      }
      process.stderr.write(`Run \`node scripts/set-version.mjs ${canonical}\` to restamp them.\n`);
      return 1;
    }
    process.stdout.write(`All ${targets.length} files that carry the version agree on ${canonical}.\n`);
    return 0;
  }
  if (positional.length !== 1) {
    printUsage();
    return 2;
  }
  const result = await applyVersion(positional[0], { versionCode });
  if (result.changes.length === 0) {
    process.stdout.write(`Already at ${result.version} (versionCode ${result.versionCode}); nothing to write.\n`);
    return 0;
  }
  process.stdout.write(
    `Stamped ${result.version} over ${result.previous}` +
    `${result.versionCode === result.previousVersionCode ? '' : ` and versionCode ${result.versionCode} over ${result.previousVersionCode}`} in:\n` +
    result.changes.map(file => `  ${file}\n`).join(''));
  process.stdout.write('README.md and AETHON_SBOM.* still describe the previous release; update them by hand.\n');
  return 0;
}

const invoked = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) {
  main(process.argv.slice(2)).then(
    code => process.exit(code),
    error => {
      process.stderr.write(`${error.message}\n`);
      process.exit(1);
    });
}
