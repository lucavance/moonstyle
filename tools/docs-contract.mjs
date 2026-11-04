import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');

// Maintained guides share the contracts recorded by the source manifests.
export const activeDocumentationFiles = [
  'README.md',
  'docs/README.md',
  'docs/architecture.md',
  'docs/api-stability.md',
  'docs/application-order-semantics.md',
  'docs/artifact-schema-v14.md',
  'docs/current-status.md',
  'docs/data-sources.md',
  'docs/dependency-license-audit.md',
  'docs/quickstart.md',
  'docs/regeneration.md',
  'docs/distribution.md',
  'docs/release-policy.md',
  'docs/ci-and-validation.md',
  'docs/roadmap.md',
  'docs/stylex-compatibility.md',
  'docs/tailwindcss-vs-stylex.md',
  'docs/authoring.md',
  'src/expressions.mbt.md',
  'src/common_values.mbt.md',
  'src/css_coverage.mbt.md',
  'src/theme_paint.mbt.md',
  'src/daily_css.mbt.md',
  'packages/moonstyle-luna/README.md',
  'tooling/README.md',
  'tools/stylex-oracle/README.md',
  'validation/README.md',
  'validation/tests/dependency-fixtures/README.md',
];

function read(filename, directory) {
  return fs.readFileSync(path.join(directory, filename), 'utf8');
}

function markdownFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (
      ['.git', '.cache', '.generated', '.mooncakes', '_build', 'dist', 'node_modules'].includes(
        entry.name,
      )
    )
      continue;
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...markdownFiles(filename));
    else if (entry.name.endsWith('.md')) files.push(filename);
  }
  return files.sort((left, right) => left.localeCompare(right));
}

function unfenced(source) {
  let fence = null;
  return source
    .replace(/<!--[\s\S]*?-->/g, '')
    .split('\n')
    .map((line) => {
      const marker = /^\s{0,3}(`{3,}|~{3,})/.exec(line)?.[1];
      if (fence !== null) {
        if (
          marker?.[0] === fence[0] &&
          marker.length >= fence.length &&
          new RegExp(`^\\s{0,3}${fence[0]}{${fence.length},}\\s*$`).test(line)
        )
          fence = null;
        return '';
      }
      if (marker) {
        fence = marker;
        return '';
      }
      return line;
    })
    .join('\n');
}

function headingAnchors(source) {
  const text = unfenced(source);
  const anchors = new Set();
  const lines = text.split('\n');
  for (const match of text.matchAll(/\b(?:id|name)=["']([^"']+)["']/g)) anchors.add(match[1]);
  for (let index = 0; index < lines.length; index += 1) {
    let heading = /^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$/.exec(lines[index])?.[1];
    if (!heading && /^ {0,3}(?:=+|-+)\s*$/.test(lines[index + 1] ?? '') && lines[index].trim()) {
      heading = lines[index].trim();
      index += 1;
    }
    if (!heading) continue;
    const base = heading
      .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/<[^>]*>/g, '')
      .toLowerCase()
      .replace(/[^\p{L}\p{M}\p{N}_\-\s]/gu, '')
      .replace(/\s/g, '-');
    let slug = base;
    for (let suffix = 1; anchors.has(slug); suffix += 1) slug = `${base}-${suffix}`;
    anchors.add(slug);
  }
  return anchors;
}

function linkTargets(source) {
  const text = unfenced(source).replace(/`+[^`\n]*`+/g, '');
  const targets = [
    ...text.matchAll(/!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|[^\s)]+)(?:\s+["'][^\n]*?["'])?\s*\)/g),
  ].map((match) => match[1]);
  const references = new Map();
  const label = (value) => value.trim().replace(/\s+/g, ' ').toLowerCase();
  for (const match of text.matchAll(/^ {0,3}\[([^\]\n]+)\]:\s*(<[^>\n]+>|\S+)/gm)) {
    references.set(label(match[1]), match[2]);
    targets.push(match[2]);
  }
  for (const match of text.matchAll(/!?\[([^\]\n]+)\]\[([^\]\n]*)\]/g)) {
    const target = references.get(label(match[2] || match[1]));
    if (target) targets.push(target);
  }
  return [...new Set(targets)];
}

function localLinkIssues(directory) {
  const issues = [];
  const anchors = new Map();
  for (const filename of markdownFiles(directory)) {
    for (let target of linkTargets(fs.readFileSync(filename, 'utf8'))) {
      if (target.startsWith('<') && target.endsWith('>')) target = target.slice(1, -1);
      if (!target || /^[a-z][a-z+.-]*:/i.test(target) || target.startsWith('//')) continue;
      const hash = target.indexOf('#');
      let destination;
      let anchor;
      try {
        destination = decodeURIComponent((hash < 0 ? target : target.slice(0, hash)).split('?')[0]);
        anchor = hash < 0 ? '' : decodeURIComponent(target.slice(hash + 1));
      } catch {
        issues.push(`${path.relative(directory, filename)} has an invalid link: ${target}`);
        continue;
      }
      const resolved = destination ? path.resolve(path.dirname(filename), destination) : filename;
      if (!fs.existsSync(resolved)) {
        issues.push(
          `${path.relative(directory, filename)} links to missing ${path.relative(directory, resolved)}`,
        );
      } else if (anchor && resolved.endsWith('.md')) {
        if (!anchors.has(resolved))
          anchors.set(resolved, headingAnchors(fs.readFileSync(resolved, 'utf8')));
        if (!anchors.get(resolved).has(anchor)) {
          issues.push(`${path.relative(directory, filename)} links to missing anchor ${target}`);
        }
      }
    }
  }
  return issues;
}

function moonModule(source) {
  return {
    name: /^name\s*=\s*"([^"]+)"/m.exec(source)?.[1],
    version: /^version\s*=\s*"([^"]+)"/m.exec(source)?.[1],
    repository: /^repository\s*=\s*"([^"]*)"/m.exec(source)?.[1],
    dependencies: Object.fromEntries(
      [...source.matchAll(/"([^"\s]+)@(\d[^"\s]*)"/g)].map((match) => [match[1], match[2]]),
    ),
  };
}

export function docsContractIssues(directory = root) {
  const issues = localLinkIssues(directory);
  for (const filename of markdownFiles(directory)) {
    const relative = path.relative(directory, filename);
    const source = fs.readFileSync(filename, 'utf8');
    if (
      /(?:^|\/)docs\/(?:evidence|adr)\//.test(relative) ||
      /(?:dependency-refresh|upstream-stylex-assessment)-\d{4}-/.test(relative) ||
      /\bphase[- ]\d+\b|\blampclaw\/style(?:-validation)?\b|old-moonstyle|current-beta-status\.md|\b(?:renamed from|completed phase plans|recorded October|planned Mooncakes module name|upstream review on)\b|adjacent reference checkout|MoonBit 0\.10\.14/i.test(
        source,
      )
    )
      issues.push(`${relative} contains superseded project history`);
    if (
      /repository\s+URL\s+(?:is\s+(?:currently\s+)?unconfigured|has\s+not\s+been\s+configured)/i.test(
        source,
      )
    )
      issues.push(`${relative} contains stale unconfigured repository wording`);
  }
  const documents = new Map();
  for (const filename of activeDocumentationFiles) {
    if (!fs.existsSync(path.join(directory, filename)))
      issues.push(`Missing active documentation: ${filename}`);
    else documents.set(filename, read(filename, directory));
  }
  const requireText = (filename, text, description = `include ${text}`) => {
    const source = documents.get(filename);
    if (source !== undefined && !source.includes(text))
      issues.push(`${filename} must ${description}`);
  };
  const table = (filename, name, value) =>
    requireText(filename, `| ${name} | ${value} |`, `record ${name} as ${value}`);

  let facts;
  try {
    const json = (filename) => JSON.parse(read(filename, directory));
    facts = {
      tools: json('toolchain.json'),
      release: json('release-status.json'),
      tooling: json('package.json'),
      oracle: json('tools/stylex-oracle/package.json'),
      api: json('src/properties/property-api.json'),
      metadata: json('src/properties/property-metadata.json'),
      coverage: json('src/properties/property-coverage.json'),
      artifact: json('validation/src/generated/styles.bundle.json'),
      lock: json('src/core/application-order.lock.json'),
      modules: ['moon.mod', 'validation/moon.mod', 'packages/moonstyle-luna/moon.mod'].map(
        (filename) => moonModule(read(filename, directory)),
      ),
    };
  } catch (error) {
    issues.push(`Cannot read documentation source of truth: ${error.message}`);
    return issues;
  }

  const repository = 'https://github.com/lucavance/moonstyle';
  const publishedLibraryDocs = new Set([
    'README.md',
    'docs/authoring.md',
    'docs/current-status.md',
    'docs/distribution.md',
    'docs/release-policy.md',
  ]);
  if (
    facts.release.schemaVersion !== 1 ||
    facts.release.developmentVersion !== facts.tooling.version ||
    !/^\d+\.\d+\.\d+$/.test(facts.release.publishedLibraryVersion)
  ) {
    issues.push(
      'release-status.json must distinguish the current development version and published library version',
    );
  }
  for (const filename of publishedLibraryDocs) {
    requireText(
      filename,
      `lampclaw/moonstyle@${facts.release.publishedLibraryVersion}`,
      'record the published library version',
    );
  }
  const upstream = 'https://github.com/meta/stylex';
  for (const prefix of ['', 'packages/moonstyle-luna/']) {
    for (const name of ['LICENSE', 'NOTICE']) {
      const filename = `${prefix}${name}`;
      if (!fs.existsSync(path.join(directory, filename))) {
        issues.push(`Missing packaged attribution: ${filename}`);
        continue;
      }
      const source = read(filename, directory);
      if (!source.includes('Copyright (c) Meta Platforms, Inc. and affiliates.'))
        issues.push(`${filename} must retain the upstream copyright`);
      if (name === 'LICENSE') {
        if (!/Copyright \(c\) \d{4}(?:-\d{4})? MoonStyle contributors/.test(source))
          issues.push(`${filename} must name MoonStyle contributors`);
        if (!source.includes('MIT License') || !source.includes('Permission is hereby granted'))
          issues.push(`${filename} must retain the MIT permission notice`);
      } else if (!source.includes(`Upstream project: ${upstream}`)) {
        issues.push(`${filename} must identify the canonical StyleX source`);
      }
      if (prefix && fs.existsSync(path.join(directory, name)) && source !== read(name, directory))
        issues.push(`${filename} must match the root ${name}`);
    }
  }
  for (const module of facts.modules) {
    if (module.repository !== repository)
      issues.push(`${module.name} repository must be ${repository}`);
  }
  if (facts.tooling.repository !== repository)
    issues.push(`package.json repository must be ${repository}`);
  for (const filename of [
    'README.md',
    'docs/authoring.md',
    'docs/distribution.md',
    'docs/quickstart.md',
  ])
    requireText(filename, repository, 'include the canonical source repository');
  for (const filename of ['README.md', 'docs/quickstart.md', 'docs/ci-and-validation.md'])
    requireText(filename, 'moon update', 'document MoonBit registry initialization');

  const status = 'docs/current-status.md';
  const propertyCount = facts.metadata.properties.length;
  table(status, 'Library, optional Luna module, private tooling', facts.tooling.version);
  table(status, 'Reviewed typed properties', propertyCount);
  table(status, 'Artifact schema', `v${facts.artifact.schemaVersion}`);
  table(status, 'Property generator schema', `v${facts.api.schemaVersion}`);
  table(status, 'Application-order semantic lock', `v${facts.lock.schemaVersion}`);
  for (const [key, name] of Object.entries({
    moonCli: 'Moon CLI',
    moonRevision: 'Moon revision',
    moonCompiler: 'Moon compiler',
    moonCore: 'Moon core',
    vitePlus: 'Vite+',
    bun: 'Bun',
    node: 'Node',
    playwright: 'Playwright',
  }))
    table(status, name, facts.tools.tools[key]);
  table(
    status,
    'Release platform',
    `Ubuntu ${facts.tools.release.osVersion} ${facts.tools.release.architecture}`,
  );

  for (const name of ['@webref/css', '@mdn/browser-compat-data', 'css-tree']) {
    table('docs/data-sources.md', `\`${name}\``, facts.tooling.devDependencies[name]);
  }
  table('docs/data-sources.md', 'Typed properties', propertyCount);
  table('docs/data-sources.md', 'WebRef properties', facts.coverage.properties.length);
  for (const [key, label] of Object.entries({
    'unsupported-grammar': 'Unsupported grammar',
    'unsafe-only': 'Unsafe-only',
    deprecated: 'Deprecated',
  }))
    table('docs/data-sources.md', label, facts.coverage.summary[key]);
  const luna = facts.modules[2];
  for (const [name, version] of Object.entries(luna.dependencies)) {
    table('packages/moonstyle-luna/README.md', `\`${name}\``, version);
  }
  const versions = new Map(
    Object.entries({
      ...facts.tooling.devDependencies,
      ...facts.tooling.overrides,
      ...facts.oracle.devDependencies,
      ...facts.oracle.overrides,
      ...Object.assign({}, ...facts.modules.map((module) => module.dependencies)),
    }),
  );
  const quickstart = documents.get('docs/quickstart.md') ?? '';
  for (const match of quickstart.matchAll(
    /<!-- consumer-file: ([^\n]+\/package\.json) -->\s*```json\n([\s\S]*?)\n```/g,
  )) {
    try {
      const manifest = JSON.parse(match[2]);
      for (const [name, version] of Object.entries({
        ...manifest.dependencies,
        ...manifest.devDependencies,
        ...manifest.overrides,
      })) {
        if (versions.has(name) && versions.get(name) !== version)
          issues.push(
            `docs/quickstart.md ${match[1]} has stale ${name}@${version}; expected ${versions.get(name)}`,
          );
      }
    } catch {
      issues.push(`docs/quickstart.md has invalid consumer manifest ${match[1]}`);
    }
  }
  for (const module of facts.modules) {
    requireText('docs/architecture.md', `\`${module.name}\``);
    if (module.version !== facts.tooling.version)
      issues.push(`${module.name} must match documented candidate ${facts.tooling.version}`);
  }
  const artifactDoc = `docs/artifact-schema-v${facts.artifact.schemaVersion}.md`;
  if (!documents.has(artifactDoc)) issues.push(`Missing current artifact contract: ${artifactDoc}`);
  requireText(artifactDoc, `# Artifact schema v${facts.artifact.schemaVersion}`);
  for (const field of Object.keys(facts.artifact)) requireText(artifactDoc, `"${field}"`);
  requireText(artifactDoc, '`policy`');
  requireText(
    'tools/stylex-oracle/README.md',
    `Babel core ${facts.oracle.devDependencies['@babel/core']}`,
  );
  requireText('docs/application-order-semantics.md', facts.artifact.semantics.profile);
  requireText('README.md', 'MoonBit is the only supported authoring language');
  requireText('README.md', 'Rabbita is the only Tier-1 framework integration');
  requireText('README.md', 'MoonStyle — Typed atomic CSS for MoonBit.');
  requireText('README.md', '为 MoonBit 提供类型安全的原子化 CSS。');
  requireText('packages/moonstyle-luna/README.md', 'Status: experimental');
  requireText('docs/release-policy.md', 'vp run validate-ci');
  for (const command of [
    'init',
    'doctor --strict',
    'upgrade --dry-run',
    'generate',
    'check',
    'watch',
  ]) {
    requireText('tooling/README.md', `moonstyle ${command}`);
  }

  for (const [filename, source] of documents) {
    for (const [pattern, expected, name] of [
      [/\bVite\+ (\d+\.\d+\.\d+(?:-[\w.-]+)?)/g, facts.tools.tools.vitePlus, 'Vite+'],
      [/\bBun (\d+\.\d+\.\d+)/g, facts.tools.tools.bun, 'Bun'],
      [/\bNode (\d+\.\d+\.\d+)/g, facts.tools.tools.node, 'Node'],
      [/\bPlaywright (\d+\.\d+\.\d+)/g, facts.tools.tools.playwright, 'Playwright'],
      [/\bMoon CLI (\d+\.\d+\.\d+)/g, facts.tools.tools.moonCli, 'Moon CLI'],
      [/\bMoonBit (\d+\.\d+\.\d+)/g, facts.tools.tools.moonCompiler.split('+')[0], 'MoonBit'],
      [/\bStyleX (\d+\.\d+\.\d+)/g, facts.oracle.devDependencies['@stylexjs/stylex'], 'StyleX'],
    ]) {
      for (const match of source.matchAll(pattern)) {
        if (match[1] !== expected)
          issues.push(`${filename} has stale ${name} ${match[1]}; expected ${expected}`);
      }
    }
    for (const match of source.matchAll(
      /\b(\d+)(?:-property (?:API|authoring|semantic\b)| (?:reviewed )?typed (?:IR )?properties\b)/g,
    )) {
      if (Number(match[1]) !== propertyCount)
        issues.push(
          `${filename} has stale typed property count ${match[1]}; expected ${propertyCount}`,
        );
    }
    for (const [pattern, expected, name] of [
      [/artifact schema v(\d+)/gi, facts.artifact.schemaVersion, 'artifact schema'],
      [/property(?: API| generator)? schema v(\d+)/gi, facts.api.schemaVersion, 'property schema'],
    ]) {
      for (const match of source.matchAll(pattern)) {
        if (Number(match[1]) !== expected)
          issues.push(`${filename} has stale ${name} v${match[1]}; expected v${expected}`);
      }
    }
    for (const match of source.matchAll(/`([^`\s]+)@(\d[^`\s]*)`/g)) {
      if (
        match[1] === 'lampclaw/moonstyle' &&
        match[2] === facts.release.publishedLibraryVersion &&
        publishedLibraryDocs.has(filename)
      )
        continue;
      if (versions.has(match[1]) && versions.get(match[1]) !== match[2]) {
        issues.push(
          `${filename} has stale ${match[1]}@${match[2]}; expected ${versions.get(match[1])}`,
        );
      }
    }
  }
  return issues;
}

export function docsContractReport(directory = root) {
  const issues = docsContractIssues(directory);
  return { schemaVersion: 1, issues, passed: issues.length === 0 };
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  const report = docsContractReport();
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (!report.passed) process.exitCode = 1;
}
