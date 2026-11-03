import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { gzipSync } from 'node:zlib';
import { extractorBuildArguments, parseMoonBuildOutput } from '../tooling/extraction.mjs';
import {
  BENCHMARK_REPORT_SCHEMA_VERSION,
  BENCHMARK_SCENARIOS,
  evaluateScenarioBudget,
  scenarioRatios,
  summarizePairedTimings,
} from './benchmark-contract.mjs';

const root = path.resolve(import.meta.dirname, '..');
const styleModule = root;
const applicationOrderLock = readJson(
  path.join(root, 'src', 'core', 'application-order.lock.json'),
);
const propertyApi = readJson(path.join(root, 'src', 'properties', 'property-api.json'));
const propertyMetadata = readJson(path.join(root, 'src', 'properties', 'property-metadata.json'));
const generatedBundle = readJson(
  path.join(root, 'validation', 'src', 'generated', 'styles.bundle.json'),
);
const semantics = {
  profile: applicationOrderLock.profile.name,
  digest: applicationOrderLock.semanticsDigest,
};
const candidate = {
  artifactSchemaVersion: generatedBundle.schemaVersion,
  propertyApiSchemaVersion: propertyApi.schemaVersion,
  propertyCount: propertyMetadata.properties.length,
  semantics,
};

function readJson(filename) {
  return JSON.parse(fs.readFileSync(filename, 'utf8'));
}

function run(command, args, options = {}) {
  const started = process.hrtime.bigint();
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    ...options,
  });
  const milliseconds = Number(process.hrtime.bigint() - started) / 1e6;
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} failed:\n${result.stdout}${result.stderr}`);
  }
  return milliseconds;
}

function balancedSample(full, adaptive, index) {
  let fullFirst;
  let fullSecond;
  let adaptiveFirst;
  let adaptiveSecond;
  if (index % 2 === 0) {
    fullFirst = full();
    adaptiveFirst = adaptive();
    adaptiveSecond = adaptive();
    fullSecond = full();
  } else {
    adaptiveFirst = adaptive();
    fullFirst = full();
    fullSecond = full();
    adaptiveSecond = adaptive();
  }
  return {
    full: (fullFirst + fullSecond) / 2,
    adaptive: (adaptiveFirst + adaptiveSecond) / 2,
  };
}

function measurePair(full, adaptive, { warmups, measuredRuns, ordering }) {
  if (ordering === 'balanced-alternating-blocks') {
    for (let index = 0; index < warmups; index += 1) balancedSample(full, adaptive, index);
    const fullSamples = [];
    const adaptiveSamples = [];
    for (let index = 0; index < measuredRuns; index += 1) {
      const sample = balancedSample(full, adaptive, index);
      fullSamples.push(sample.full);
      adaptiveSamples.push(sample.adaptive);
    }
    return summarizePairedTimings(fullSamples, adaptiveSamples);
  }
  for (let index = 0; index < warmups; index += 1) {
    if (index % 2 === 0) {
      full();
      adaptive();
    } else {
      adaptive();
      full();
    }
  }
  const fullSamples = [];
  const adaptiveSamples = [];
  for (let index = 0; index < measuredRuns; index += 1) {
    if (index % 2 === 0) {
      fullSamples.push(full());
      adaptiveSamples.push(adaptive());
    } else {
      adaptiveSamples.push(adaptive());
      fullSamples.push(full());
    }
  }
  return summarizePairedTimings(fullSamples, adaptiveSamples);
}

function semanticDigest(value) {
  return `sha256:${createHash('sha256').update(JSON.stringify(value)).digest('hex')}`;
}

function writeJson(filename, value) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(filename, `${JSON.stringify(value)}\n`);
}

function createScenario(parent, name, configuration) {
  const { modules, rules, warmups, measuredRuns } = configuration;
  const directory = path.join(parent, name);
  fs.mkdirSync(path.join(directory, 'styles'), { recursive: true });
  fs.mkdirSync(path.join(directory, 'extractor'), { recursive: true });
  fs.mkdirSync(path.join(directory, 'src', 'generated'), { recursive: true });
  fs.writeFileSync(
    path.join(directory, 'moon.mod'),
    `name = ${JSON.stringify(`benchmark/${name}`)}\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.1.0" }\n`,
  );
  fs.writeFileSync(
    path.join(directory, 'moon.work'),
    `members = [".", ${JSON.stringify(styleModule)}]\n`,
  );
  fs.writeFileSync(path.join(directory, 'styles', 'moon.pkg'), 'import { "lampclaw/moonstyle" }\n');
  fs.writeFileSync(
    path.join(directory, 'extractor', 'moon.pkg'),
    [
      'import {',
      `  "benchmark/${name}/styles",`,
      '  "lampclaw/moonstyle/extract/cli",',
      '}',
      'supported_targets = "native"',
      'pkgtype(kind: "executable")',
      '',
    ].join('\n'),
  );
  fs.writeFileSync(
    path.join(directory, 'extractor', 'main.mbt'),
    '///|\nfn main { @cli.run(@styles.registry()) }\n',
  );

  const rulesPerModule = Math.floor(rules / modules);
  const mappingsPackage = `benchmark/${name}/src/generated`;
  const references = [];
  const bundlePaths = [];
  for (let moduleIndex = 0; moduleIndex < modules; moduleIndex += 1) {
    const moduleName = `benchmark/${name}/dependency-${moduleIndex}`;
    const bundleRules = Array.from({ length: rulesPerModule }, (_, ruleIndex) => {
      const suffix = `${moduleIndex}-${ruleIndex}`;
      return {
        property: 'color',
        className: `x-${name}-${suffix}`,
        ltr: `.x-${name}-${suffix}{color:rgb(${ruleIndex % 255} 40 80)}`,
        rtl: null,
        priority100: 300000,
      };
    });
    const semantic = {
      schemaVersion: candidate.artifactSchemaVersion,
      module: moduleName,
      mappingsPackage: `${moduleName}/generated`,
      semantics,
      directDependencies: [],
      dependencyClosure: [],
      contracts: [],
      namespaces: [],
      rules: bundleRules,
      globals: [],
      recipes: [],
      markers: [],
      viewTransitionClasses: [],
    };
    const semanticDigestValue = semanticDigest(semantic);
    const bundlePath = path.join(directory, 'bundles', `dependency-${moduleIndex}.json`);
    writeJson(bundlePath, { ...semantic, semanticDigest: semanticDigestValue });
    references.push({ module: moduleName, semanticDigest: semanticDigestValue });
    bundlePaths.push(bundlePath);
  }
  const moonReferences = references
    .map(
      (reference) =>
        `      @moonstyle.dependency_ref("${reference.module}", "${reference.semanticDigest}"),`,
    )
    .join('\n');
  fs.writeFileSync(
    path.join(directory, 'styles', 'styles.mbt'),
    [
      '///|',
      'pub fn registry() -> @moonstyle.Registry {',
      `  @moonstyle.registry("benchmark/${name}/app", [], dependencies=[`,
      moonReferences,
      '  ])',
      '}',
      '',
    ].join('\n'),
  );

  const build = spawnSync('moon', extractorBuildArguments('extractor', 'release'), {
    cwd: directory,
    encoding: 'utf8',
  });
  if (build.status !== 0) {
    throw new Error(`Moon extractor build failed:\n${build.stdout}${build.stderr}`);
  }
  const { artifactPaths } = parseMoonBuildOutput(build.stdout, build.stderr);
  const executables = artifactPaths.filter((filename) => filename.endsWith('.exe'));
  if (executables.length !== 1) {
    throw new Error(`Expected one native extractor artifact, got ${executables.length}`);
  }
  const executable = path.resolve(directory, executables[0]);
  const identity = createHash('sha256').update(fs.readFileSync(executable));
  for (const bundlePath of bundlePaths) identity.update(fs.readFileSync(bundlePath));
  identity.update(mappingsPackage);
  const environment = {
    ...process.env,
    MOONSTYLE_CACHE_IDENTITY: identity.digest('hex'),
  };
  const cacheDirectory = path.join(directory, 'cache');
  const common = [
    '--tooling-protocol',
    '1',
    '--cache-dir',
    cacheDirectory,
    '--mappings-package',
    mappingsPackage,
    ...bundlePaths.flatMap((bundlePath) => ['--dependency-bundle', bundlePath]),
  ];
  run(executable, common, { cwd: directory, env: environment });
  const timings = measurePair(
    () => run(executable, [...common, '--no-cache'], { cwd: directory, env: environment }),
    () => run(executable, common, { cwd: directory, env: environment }),
    configuration,
  );
  const { speedup, p95Ratio } = scenarioRatios(timings);
  const budget = evaluateScenarioBudget(name, timings);
  return {
    modules,
    rules,
    measurement: { warmups, measuredRuns, ordering: configuration.ordering },
    timings,
    speedup,
    p95Ratio,
    budget,
    budgetMet: budget.met,
  };
}

function fileSize(filename) {
  const content = fs.readFileSync(filename);
  return { rawBytes: content.length, gzipBytes: gzipSync(content).length };
}

function commandVersion(command, args) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8' });
  return `${result.stdout}${result.stderr}`.trim().split('\n')[0];
}

function outputFilename(args) {
  if (args.length === 0) return null;
  if (args.length !== 2 || args[0] !== '--output' || !args[1]) {
    throw new Error('usage: node tools/benchmark.mjs [--output benchmarks/<report>.json]');
  }
  const benchmarkDirectory = path.join(root, 'benchmarks');
  const filename = path.resolve(root, args[1]);
  if (
    !filename.startsWith(`${benchmarkDirectory}${path.sep}`) ||
    path.extname(filename) !== '.json'
  ) {
    throw new Error('benchmark output must be a JSON file inside benchmarks/');
  }
  return filename;
}

function atomicWriteReport(filename, report) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  const temporary = `${filename}.tmp.json`;
  try {
    fs.writeFileSync(temporary, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
    run('vp', ['fmt', temporary, '--write']);
    fs.renameSync(temporary, filename);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
}

const reportFilename = outputFilename(process.argv.slice(2));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'style-benchmark-'));
try {
  const scenarios = Object.fromEntries(
    Object.entries(BENCHMARK_SCENARIOS).map(([name, configuration]) => [
      name,
      createScenario(temporary, name, configuration),
    ]),
  );
  const report = {
    schemaVersion: BENCHMARK_REPORT_SCHEMA_VERSION,
    recordedAt: new Date().toISOString(),
    candidate,
    machine: {
      platform: os.platform(),
      release: os.release(),
      architecture: os.arch(),
      cpu: os.cpus()[0]?.model ?? 'unknown',
      logicalCpus: os.cpus().length,
    },
    toolchain: {
      moon: commandVersion('moon', ['version']),
      vitePlus: commandVersion('vp', ['--version']),
      bun: commandVersion('bun', ['--version']),
      node: process.version,
    },
    scenarios,
    budgetsMet: Object.values(scenarios).every((scenario) => scenario.budgetMet),
    sizes: {
      css: fileSize(path.join(root, 'validation/src/generated/styles.generated.css')),
      mappings: fileSize(path.join(root, 'validation/src/generated/styles.generated.mbt')),
      mappingsManifest: fileSize(path.join(root, 'validation/src/generated/moon.pkg')),
      bundle: fileSize(path.join(root, 'validation/src/generated/styles.bundle.json')),
    },
  };
  if (reportFilename) atomicWriteReport(reportFilename, report);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (!report.budgetsMet) process.exitCode = 1;
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
