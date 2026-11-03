import fs from 'node:fs';
import path from 'node:path';
import { gzipSync } from 'node:zlib';
import { CANDIDATE_BENCHMARK_REPORTS, candidatePerformanceIssues } from './benchmark-contract.mjs';
import { docsContractIssues } from './docs-contract.mjs';
import {
  BABEL_VERSION,
  ORACLE_PACKAGE_VERSIONS,
  STYLEX_RELEASE_VERSION,
  oracleReleaseContractIssues,
} from './stylex-oracle/release-contract.mjs';

const root = path.resolve(import.meta.dirname, '..');
const styleModule = root;
const manifest = fs.readFileSync(path.join(styleModule, 'moon.mod'), 'utf8');
const lunaManifest = fs.readFileSync(
  path.join(root, 'packages', 'moonstyle-luna', 'moon.mod'),
  'utf8',
);
const productManifests = [manifest, lunaManifest];
const rootManifest = fs.readFileSync(path.join(root, 'moon.mod'), 'utf8');
const field = (source, name) => source.match(new RegExp(`^${name} = "([^"]*)"$`, 'm'))?.[1] ?? '';
const canonicalRepository = field(rootManifest, 'repository');
const checks = [];
const check = (name, passed, detail) => checks.push({ name, passed, detail });
const oracleRoot = path.join(root, 'tools', 'stylex-oracle');
const requireOracle = process.argv.includes('--require-oracle');

function filesUnder(directory, predicate) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (['node_modules', '.generated', '_build', '_build.native', 'dist'].includes(entry.name))
        continue;
      files.push(...filesUnder(filename, predicate));
    } else if (predicate(filename)) files.push(filename);
  }
  return files;
}

function installedPackages(directory, output = new Map()) {
  if (!fs.existsSync(directory)) return output;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
    const candidate = path.join(directory, entry.name);
    if (entry.name.startsWith('@')) {
      installedPackages(candidate, output);
      continue;
    }
    const manifestPath = path.join(candidate, 'package.json');
    if (!fs.existsSync(manifestPath)) continue;
    const packageManifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    output.set(`${packageManifest.name}@${packageManifest.version}`, {
      directory: candidate,
      manifest: packageManifest,
    });
    installedPackages(path.join(candidate, 'node_modules'), output);
  }
  return output;
}

function licenseOf(package_) {
  const declared = package_.manifest.license;
  if (typeof declared === 'string' && declared.trim()) return declared;
  if (Array.isArray(declared) && declared.length > 0) {
    return declared.map((entry) => entry.type ?? entry).join(' OR ');
  }
  const licenseFile = fs
    .readdirSync(package_.directory)
    .find((filename) => /^licen[sc]e(?:\.|$)/i.test(filename));
  return licenseFile ? `SEE ${licenseFile}` : null;
}

function auditLicenses(installed) {
  const licenses = {};
  const unknown = [];
  for (const [identity, package_] of [...installed].sort(([left], [right]) =>
    left.localeCompare(right),
  )) {
    const license = licenseOf(package_);
    if (license) licenses[identity] = license;
    else unknown.push(identity);
  }
  return { licenses, unknown };
}
const installed = installedPackages(path.join(root, 'node_modules'));
const { licenses: dependencyLicenses, unknown: unknownLicenses } = auditLicenses(installed);
const rootCompilerPackages = [...installed.keys()].filter((identity) =>
  /^@(?:babel\/(?:core|parser|traverse|types)|stylexjs\/)/.test(identity),
);
const oracleInstalled = installedPackages(path.join(oracleRoot, 'node_modules'));
const { licenses: oracleDependencyLicenses, unknown: unknownOracleLicenses } =
  auditLicenses(oracleInstalled);
const missingOracleDependencies = Object.entries(ORACLE_PACKAGE_VERSIONS)
  .map(([name, version]) => `${name}@${version}`)
  .filter((identity) => !oracleInstalled.has(identity));

const moonDependencyLicenses = {};
for (const match of productManifests.join('\n').matchAll(/"([^"]+)@([^"]+)"/g)) {
  const [, name, version] = match;
  if (name === 'lampclaw/moonstyle') continue;
  const dependencyRoot = path.join(root, '.mooncakes', name);
  const legacyManifest = path.join(dependencyRoot, 'moon.mod');
  const jsonManifest = path.join(dependencyRoot, 'moon.mod.json');
  let license = null;
  if (fs.existsSync(legacyManifest)) {
    const dependencyManifest = fs.readFileSync(legacyManifest, 'utf8');
    try {
      license = JSON.parse(dependencyManifest).license ?? null;
    } catch {
      license = dependencyManifest.match(/^license = "([^"]+)"$/m)?.[1];
    }
  } else if (fs.existsSync(jsonManifest)) {
    license = JSON.parse(fs.readFileSync(jsonManifest, 'utf8')).license ?? null;
  }
  moonDependencyLicenses[`${name}@${version}`] = license ?? null;
}

const packageManifest = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const oracleManifest = JSON.parse(fs.readFileSync(path.join(oracleRoot, 'package.json'), 'utf8'));
const automationFiles = [
  path.join(root, 'validation', 'entry.mjs'),
  path.join(root, 'validation', 'vite.config.mjs'),
  path.join(root, 'vite.config.mjs'),
  ...filesUnder(
    path.join(root, 'tools'),
    (filename) =>
      filename.endsWith('.mjs') &&
      !['docs-contract.mjs', 'release-audit.mjs'].includes(path.basename(filename)),
  ),
  ...filesUnder(path.join(root, 'tooling'), (filename) => /\.(?:mjs|js|ts)$/.test(filename)),
  ...filesUnder(path.join(root, 'templates'), (filename) => /\.(?:mjs|js|ts)$/.test(filename)),
  ...filesUnder(path.join(root, '.github', 'workflows'), (filename) => /\.ya?ml$/.test(filename)),
];
const automation = [
  ...automationFiles.map((filename) => fs.readFileSync(filename, 'utf8')),
  JSON.stringify(packageManifest.scripts ?? {}),
].join('\n');

const propertyApi = JSON.parse(
  fs.readFileSync(path.join(styleModule, 'src', 'properties', 'property-api.json'), 'utf8'),
);
const propertyMetadata = JSON.parse(
  fs.readFileSync(path.join(styleModule, 'src', 'properties', 'property-metadata.json'), 'utf8'),
);
const applicationOrderLock = JSON.parse(
  fs.readFileSync(path.join(styleModule, 'src', 'core', 'application-order.lock.json'), 'utf8'),
);
const generatedBundle = JSON.parse(
  fs.readFileSync(path.join(root, 'validation', 'src', 'generated', 'styles.bundle.json'), 'utf8'),
);
const expectedCandidate = {
  artifactSchemaVersion: generatedBundle.schemaVersion,
  propertyApiSchemaVersion: propertyApi.schemaVersion,
  propertyCount: propertyMetadata.properties.length,
  semantics: {
    profile: applicationOrderLock.profile.name,
    digest: applicationOrderLock.semanticsDigest,
  },
};
const fileSize = (filename) => {
  const content = fs.readFileSync(filename);
  return { rawBytes: content.length, gzipBytes: gzipSync(content).length };
};
const expectedSizes = {
  css: fileSize(path.join(root, 'validation', 'src', 'generated', 'styles.generated.css')),
  mappings: fileSize(path.join(root, 'validation', 'src', 'generated', 'styles.generated.mbt')),
  mappingsManifest: fileSize(path.join(root, 'validation', 'src', 'generated', 'moon.pkg')),
  bundle: fileSize(path.join(root, 'validation', 'src', 'generated', 'styles.bundle.json')),
};
const candidateReports = [];
const candidateReportReadIssues = [];
for (const relativePath of CANDIDATE_BENCHMARK_REPORTS) {
  try {
    candidateReports.push(JSON.parse(fs.readFileSync(path.join(root, relativePath), 'utf8')));
  } catch (error) {
    candidateReportReadIssues.push(`${relativePath}: ${error.message}`);
  }
}
const performanceIssues = [
  ...candidateReportReadIssues,
  ...(candidateReportReadIssues.length === 0
    ? candidatePerformanceIssues(candidateReports, expectedCandidate, expectedSizes)
    : []),
];

check('version', field(manifest, 'version') === '0.1.0', field(manifest, 'version'));
check('license', field(manifest, 'license') === 'MIT', field(manifest, 'license'));
check(
  'luna-adapter-version',
  field(lunaManifest, 'version') === '0.1.0',
  field(lunaManifest, 'version'),
);
check(
  'luna-adapter-license',
  field(lunaManifest, 'license') === 'MIT',
  field(lunaManifest, 'license'),
);
const repositories = [
  field(rootManifest, 'repository'),
  field(manifest, 'repository'),
  field(lunaManifest, 'repository'),
  packageManifest.repository ?? '',
];
check(
  'repository-metadata',
  canonicalRepository === 'https://github.com/lucavance/moonstyle' &&
    repositories.every((repository) => repository === canonicalRepository),
  repositories.join(', '),
);
check('license-file', fs.existsSync(path.join(root, 'LICENSE')), 'LICENSE');
check('notice-file', fs.existsSync(path.join(root, 'NOTICE')), 'NOTICE');
check(
  'javascript-tooling-package',
  packageManifest.name === '@lampclaw/moonstyle-tooling' &&
    packageManifest.version === '0.1.0' &&
    packageManifest.private === true &&
    packageManifest.license === 'MIT' &&
    packageManifest.exports?.['./vite'] === './tooling/vite-plugin-moonstyle.mjs' &&
    packageManifest.bin?.['moonstyle'] === './tooling/cli.mjs',
  `${packageManifest.name}@${packageManifest.version}; private=${packageManifest.private}`,
);
check(
  'javascript-tooling-not-copied',
  !fs.existsSync(path.join(root, 'templates', 'rabbita-vite', 'vite-plugin-moonstyle.mjs')) &&
    !fs.existsSync(path.join(root, 'templates', 'rabbita-vite', 'moonstyle-inspector-client.mjs')),
  '@lampclaw/moonstyle-tooling/vite owns the Vite plugin and inspector runtime',
);
check(
  'javascript-tooling-lock-name',
  fs
    .readFileSync(path.join(root, 'bun.lock'), 'utf8')
    .includes('"name": "@lampclaw/moonstyle-tooling"'),
  '@lampclaw/moonstyle-tooling',
);
check(
  'source-module-boundary',
  field(manifest, 'name') === 'lampclaw/moonstyle' &&
    field(manifest, 'source') === 'src' &&
    ['examples', 'cmd', 'demo', 'templates', 'tools'].every(
      (relative) => !fs.existsSync(path.join(styleModule, 'src', relative)),
    ) &&
    filesUnder(path.join(styleModule, 'src'), (filename) => filename.endsWith('moon.pkg')).every(
      (filename) => !fs.readFileSync(filename, 'utf8').includes('lampclaw/moonstyle-validation'),
    ),
  'The root module compiles src/ independently of validation/ and repository tooling',
);
check(
  'no-registry-automation',
  !/\bmoon\s+(?:publish|package|register)\b|\bnpm\s+publish\b|\b(?:MOONCAKES|MOONBIT|NPM)_(?:TOKEN|SECRET)\b|\bgh\s+release\b|\bgit\s+tag\b|actions\/create-release|softprops\/action-gh-release/i.test(
    automation,
  ),
  `${automationFiles.length} automation sources; publication and tagging require explicit maintainer operations`,
);
check('javascript-licenses', unknownLicenses.length === 0, unknownLicenses.join(', ') || 'known');
check(
  'stylex-oracle-package',
  oracleManifest.private === true &&
    Object.entries(ORACLE_PACKAGE_VERSIONS).every(
      ([name, version]) => oracleManifest.devDependencies?.[name] === version,
    ) &&
    fs.existsSync(path.join(oracleRoot, 'bun.lock')) &&
    Array.isArray(packageManifest.workspaces) &&
    packageManifest.workspaces.length === 1 &&
    packageManifest.workspaces[0] === 'validation',
  `private independent package; Babel ${BABEL_VERSION} and StyleX ${STYLEX_RELEASE_VERSION}`,
);
const oracleReleaseIssues = oracleReleaseContractIssues({
  manifest: oracleManifest,
  lockText: fs.existsSync(path.join(oracleRoot, 'bun.lock'))
    ? fs.readFileSync(path.join(oracleRoot, 'bun.lock'), 'utf8')
    : null,
});
check(
  'stylex-oracle-release-contract',
  oracleReleaseIssues.length === 0,
  oracleReleaseIssues.join('; ') || `StyleX ${STYLEX_RELEASE_VERSION}`,
);
check(
  'root-compiler-isolation',
  rootCompilerPackages.length === 0 &&
    !Object.keys(packageManifest.devDependencies ?? {}).some((name) =>
      /^@(?:babel|stylexjs)\//.test(name),
    ),
  rootCompilerPackages.length > 0
    ? `unexpected root packages: ${rootCompilerPackages.join(', ')}; reinstall root dependencies in a clean node_modules directory`
    : 'Babel compiler and StyleX are outside the root graph',
);
check(
  'oracle-javascript-licenses',
  unknownOracleLicenses.length === 0 && (!requireOracle || missingOracleDependencies.length === 0),
  unknownOracleLicenses.join(', ') ||
    (requireOracle && missingOracleDependencies.length > 0
      ? `missing ${missingOracleDependencies.join(', ')}; run vp run install-oracle`
      : oracleInstalled.size > 0
        ? `${oracleInstalled.size} installed oracle dependencies have known licenses`
        : 'oracle is not installed; strict CI requires vp run install-oracle'),
);
const unknownMoonLicenses = Object.entries(moonDependencyLicenses)
  .filter(([, license]) => !license)
  .map(([identity]) => identity);
check(
  'moonbit-licenses',
  unknownMoonLicenses.length === 0,
  unknownMoonLicenses.join(', ') || 'known',
);
check(
  'candidate-performance-evidence',
  performanceIssues.length === 0,
  performanceIssues.join('; ') || 'two reproducible benchmark-schema-v4 reports pass every budget',
);
const documentationIssues = docsContractIssues();
check(
  'documentation-contract',
  documentationIssues.length === 0,
  documentationIssues.join('; ') || 'active documentation matches implemented contracts',
);

const report = {
  version: field(manifest, 'version'),
  repository: canonicalRepository || null,
  distribution: ['git-commit', 'local-path'],
  javascriptTooling: {
    name: packageManifest.name,
    version: packageManifest.version,
    private: packageManifest.private,
    protocolVersion: 1,
  },
  mooncakes: false,
  checks,
  dependencyLicenses,
  oracleDependencyLicenses,
  moonDependencyLicenses,
  passed: checks.every((item) => item.passed),
};
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
if (!report.passed) process.exitCode = 1;
