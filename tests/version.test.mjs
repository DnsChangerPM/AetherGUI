import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { applyVersion, checkVersions, normalizeVersion, read, readAndroidVersionCode, repoRoot, targets, VERSION_PATTERN } from '../scripts/set-version.mjs';

const run = promisify(execFile);
const cli = (...args) => run(process.execPath, [join(repoRoot, 'scripts/set-version.mjs'), ...args], { cwd: repoRoot });

const DIFFERENT = '9.9.9';

test('Every version stamp in the repository agrees with src-tauri/tauri.conf.json', async () => {
  const { canonical, mismatches } = await checkVersions();
  assert.match(canonical, VERSION_PATTERN);
  assert.deepEqual(mismatches, [], 'Half-stamped versions produce artifacts named after a version nothing was built from.');
  // The Rust manifest and the lockfile have to agree or `cargo test --locked` in the release
  // workflow fails before anything is built.
  const manifest = await read('src-tauri/Cargo.toml');
  const lock = await read('src-tauri/Cargo.lock');
  assert.equal(/^version = "([^"]+)"$/m.exec(manifest)[1], canonical);
  assert.equal(/\[\[package\]\]\r?\nname = "aether-gui"\r?\nversion = "([^"]+)"/.exec(lock)[1], canonical);
});

test('Stamping a new version rewrites every stamp and nothing else', async () => {
  const { canonical } = await checkVersions();
  const committedCode = await readAndroidVersionCode();
  for (const target of targets) {
    const original = await read(target.file);
    const stamped = target.update(original, DIFFERENT, { versionCode: committedCode + 1 });
    assert.notEqual(stamped, original, `${target.file} did not change`);
    const reported = target.current(stamped);
    assert.ok(reported.length > 0, `${target.file} reports no version after stamping`);
    for (const value of reported) assert.equal(value, DIFFERENT, `${target.file} still reports ${value}`);

    const before = original.split('\n');
    const after = stamped.split('\n');
    assert.equal(before.length, after.length, `${target.file} changed line count`);
    const changed = before.filter((line, index) => line !== after[index]).length;
    assert.ok(changed >= 1 && changed <= reported.length + 1,
      `${target.file} rewrote ${changed} line(s) for ${reported.length} stamp(s); a version stamp should be one line each`);

    // Reversible: putting the real version back reproduces the file byte for byte, so the
    // edit touched only the version text and not the formatting around it.
    assert.equal(target.update(stamped, canonical, { versionCode: committedCode }), original,
      `${target.file} does not round-trip`);
  }
});

test('Version strings that are history, not stamps, are left alone', async () => {
  const stamped = targets.map(target => target.file);
  // AETHON_SBOM.json also lists the crates derive_more and derive_more-impl at 2.1.1, and
  // VpnConnectionController.java and update.rs mention 2.1.1 as past behaviour and test data.
  // A global find-and-replace would rewrite all of them.
  for (const file of ['AETHON_SBOM.json', 'AETHON_SBOM.md', 'README.md',
                      'android/app/src/main/java/com/firstham/aethergui/VpnConnectionController.java',
                      'src-tauri/src/update.rs']) {
    assert.ok(!stamped.includes(file), `${file} must not be restamped automatically`);
  }
  const sbom = await read('AETHON_SBOM.json');
  assert.match(sbom, /"name": "derive_more",\s*\n\s*"version": "2\.1\.1"/);
  assert.match(await read('android/app/src/main/java/com/firstham/aethergui/VpnConnectionController.java'), /v2\.1\.1 stored/);
  assert.match(await read('src-tauri/src/update.rs'), /installer_asset_name_for\("2\.1\.1"/);
});

test('Only a plain three-part version is accepted, and a bad one writes nothing', async () => {
  // Tags are v-prefixed and the workflow passes one straight through.
  assert.equal(normalizeVersion('v2.2.0'), '2.2.0');
  assert.equal(normalizeVersion(' 2.2.0 '), '2.2.0');
  for (const bad of ['2.2', '2.2.0-beta', '2.2.0+build', '2.2.0.1', 'v', '', undefined]) {
    assert.throws(() => normalizeVersion(bad), /not a version this project can build/, `${bad} should be rejected`);
    await assert.rejects(() => applyVersion(bad), /not a version this project can build/);
  }
  const { mismatches } = await checkVersions();
  assert.deepEqual(mismatches, [], 'A rejected version must not have written anything.');
});

test('The release workflow asks for the version and applies it before building', async () => {
  const workflow = await read('.github/workflows/release.yml');
  assert.match(workflow, /workflow_dispatch:\s*\n\s*inputs:\s*\n(?:\s*#[^\n]*\n)*\s*app_version:/);
  assert.match(workflow, /AETHON_REQUESTED_VERSION: \$\{\{ inputs\.app_version \}\}/);
  const step = workflow.slice(workflow.indexOf('id: version'), workflow.indexOf('- name: Install dependencies'));
  assert.match(step, /node scripts\/set-version\.mjs \$version/);
  assert.match(step, /node scripts\/set-version\.mjs --check/);
  assert.match(step, /"version=\$version" \| Add-Content \$env:GITHUB_OUTPUT/);
  // The stamp has to happen before npm ci, which reads package.json.
  assert.ok(workflow.indexOf('Resolve the application version') < workflow.indexOf('- name: Install dependencies'));
  assert.ok(workflow.indexOf('Resolve the application version') < workflow.indexOf('npm run fetch:core'));
  assert.match(workflow, /version: \$\{\{ steps\.version\.outputs\.version \}\}/);
  assert.match(workflow, /# Aethon VPN v\$\{\{ needs\.build\.outputs\.version \}\}/);
  assert.doesNotMatch(workflow, /# Aethon VPN v2\.1\.1/);
});

test('Digests are computed without depending on the Get-FileHash cmdlet', async () => {
  // The hosted runner failed fetch-aether.ps1 with "The term 'Get-FileHash' is not recognized
  // as the name of a cmdlet", which stopped the release at the step that verifies the download.
  const helper = await read('scripts/sha256.ps1');
  assert.match(helper, /function Get-Sha256Hex/);
  assert.match(helper, /\[System\.Security\.Cryptography\.SHA256\]::Create\(\)/);

  const hashing = ['sha256.ps1', 'fetch-aether.ps1', 'fetch-xray.ps1', 'fetch-psiphon.ps1', 'package-release.ps1'];
  for (const name of hashing) {
    const script = await read(`scripts/${name}`);
    if (name !== 'sha256.ps1') {
      assert.match(script, /\. \(Join-Path \$PSScriptRoot "sha256\.ps1"\)/, `${name} does not load the helper`);
      assert.match(script, /Get-Sha256Hex -Path/, `${name} does not hash through the helper`);
    }
    for (const line of script.split('\n')) {
      // Comments explain the cmdlet this replaces; only executable text matters.
      assert.doesNotMatch(line.replace(/#.*$/, ''), /Get-FileHash/, `${name} still calls Get-FileHash: ${line.trim()}`);
    }
  }
  const workflow = await read('.github/workflows/release.yml');
  for (const line of workflow.split('\n')) {
    assert.doesNotMatch(line.replace(/#.*$/, ''), /Get-FileHash/, `the workflow still calls Get-FileHash: ${line.trim()}`);
  }
  assert.match(workflow, /\. \(Join-Path \$env:GITHUB_WORKSPACE 'scripts\/sha256\.ps1'\)/);
});

test('The command line reports the committed version and refuses to guess', async () => {
  const { canonical } = await checkVersions();
  assert.match((await cli('--check')).stdout, /agree on \d+\.\d+\.\d+/);
  assert.equal((await cli('--print')).stdout.trim(), canonical);
  // No version and no flag is a usage error, not a silent no-op.
  await assert.rejects(() => cli(), /usage: node scripts\/set-version\.mjs/);
  await assert.rejects(() => cli('--nope'), /usage: node scripts\/set-version\.mjs/);
  await assert.rejects(() => cli('2.2.0', '--version-code', 'soon'), /is not an integer versionCode/);
});
