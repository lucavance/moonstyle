import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { generateProperties } from './generate-properties.mjs';
import { readApplicationOrderLock } from './application-order.mjs';
import { discoverDependencyBundles, loadStyleConfig } from './style-config.mjs';
import { extractorBuildArguments, parseMoonBuildOutput } from '../tooling/extraction.mjs';

const root = path.resolve(import.meta.dirname, '..');

const applicationRoot = path.join(root, 'validation');
let extractor;
const styleConfig = loadStyleConfig(applicationRoot);

export function extractionCacheIdentity(
  dependencyBundles = [],
  packageName = styleConfig.mappingsPackage,
) {
  const digest = createHash('sha256');
  digest.update(fs.readFileSync(extractor));
  digest.update(packageName);
  for (const filename of dependencyBundles) {
    const resolved = path.resolve(applicationRoot, filename);
    digest.update(path.basename(resolved));
    digest.update(fs.readFileSync(resolved));
  }
  return digest.digest('hex');
}

export function buildStyles({ propertiesGenerated = false, check = false } = {}) {
  const metadata = propertiesGenerated
    ? JSON.parse(fs.readFileSync(path.join(root, 'src/properties/property-metadata.json'), 'utf8'))
    : generateProperties();
  readApplicationOrderLock(metadata);
  const configuredBundles = (process.env.STYLE_DEPENDENCY_BUNDLES ?? '')
    .split(path.delimiter)
    .filter(Boolean);
  const dependencyBundles =
    configuredBundles.length > 0
      ? configuredBundles
      : discoverDependencyBundles(applicationRoot, styleConfig.dependencyRoots);
  const dependencyArguments = dependencyBundles.flatMap((filename) => [
    '--dependency-bundle',
    filename,
  ]);
  const build = spawnSync('moon', extractorBuildArguments('cmd/style_extract', 'release'), {
    cwd: applicationRoot,
    encoding: 'utf8',
  });
  if (build.error) throw build.error;
  if (build.status !== 0) throw new Error(`${build.stdout}${build.stderr}`);
  const { artifactPaths } = parseMoonBuildOutput(build.stdout, build.stderr);
  if (artifactPaths.length !== 1) throw new Error('Expected exactly one native extractor artifact');
  [extractor] = artifactPaths;
  const result = spawnSync(
    extractor,
    [
      '--tooling-protocol',
      '1',
      '--mappings-package',
      styleConfig.mappingsPackage,
      '--css-output',
      styleConfig.outputs.css,
      '--mappings-output',
      styleConfig.outputs.mappings,
      '--mappings-manifest-output',
      styleConfig.outputs.mappingsManifest,
      '--bundle-output',
      styleConfig.outputs.bundle,
      '--cache-dir',
      styleConfig.cacheDirectory,
      ...(check ? ['--check'] : []),
      ...dependencyArguments,
    ],
    {
      cwd: applicationRoot,
      encoding: 'utf8',
      env: {
        ...process.env,
        MOONSTYLE_CACHE_IDENTITY: extractionCacheIdentity(
          dependencyBundles,
          styleConfig.mappingsPackage,
        ),
      },
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${result.stdout}${result.stderr}`);
  process.stdout.write(result.stdout);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  Promise.resolve()
    .then(async () => {
      const check = process.argv.includes('--check');
      if (check) {
        buildStyles({ propertiesGenerated: true, check: true });
        return;
      }
      const metadata = generateProperties();
      const { generateApplicationOrder } = await import('./generate-application-order.mjs');
      generateApplicationOrder();
      buildStyles({
        propertiesGenerated: true,
        check: false,
      });
      return metadata;
    })
    .catch((error) => {
      console.error(error.stack ?? error);
      process.exitCode = 1;
    });
}
