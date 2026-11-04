/**
 * The product tracks a published StyleX release.  Keep this contract separate
 * from the semantic lock so provenance can be checked without changing the
 * lock schema or the generated MoonBit table.
 */
export const STYLEX_RELEASE_VERSION = '0.19.1';
export const STYLEX_RELEASE_TAG = '0.19.1';
export const STYLEX_RELEASE_COMMIT = '1fcb9a51cbecad2c82255e0f4b45cc072fa1a95a';
export const BABEL_VERSION = '8.0.9';

export const ORACLE_PACKAGE_VERSIONS = Object.freeze({
  '@babel/core': BABEL_VERSION,
  '@stylexjs/babel-plugin': STYLEX_RELEASE_VERSION,
  '@stylexjs/shared': STYLEX_RELEASE_VERSION,
  '@stylexjs/stylex': STYLEX_RELEASE_VERSION,
});

const packageIntegrities = Object.freeze({
  '@babel/core':
    'sha512-wXtyKlpR/pXf/u0vmib+OBakQaIzLglLcRoKpWxCHW/whqq7YfQYPD0IAAl9H/evi40MyLIjYYdvb6N+9DI2yA==',
  '@stylexjs/babel-plugin':
    'sha512-Ig3crX6MuGWDEAx+f89aLxTQUWVeEc2Aco2moIdcObyvo7hZJgU26rxJN3k7geFjhi+5dfna6TNR8iTRK0PQGA==',
  '@stylexjs/shared':
    'sha512-oFBtW0NPNLJOT1gLweWRNKrIJHjJMwOmSV7fgd6ewok4fwb/Nh95PEaYGKu+ZONk0nNghjLFfOwiIsxJdvh3TQ==',
  '@stylexjs/stylex':
    'sha512-JwNFm0MOYPqi+M4Ax5Un4ZxfZp4HEAX2sAWetZ88KALFcv1eEiHNJs75oO3V3U7RVWnzfkiM8i9eBowC3hqgUw==',
});

function parseOracleLock(lockText) {
  // Bun emits JSON with trailing commas. Protect strings while removing them.
  return JSON.parse(
    lockText.replace(/("(?:\\.|[^"\\])*")|,\s*(?=[}\]])/g, (match, quoted) => quoted ?? ''),
  );
}

/**
 * Validate the parts of the isolated oracle that are reproducible from a
 * checkout.  The git commit is retained as release provenance because npm
 * package manifests do not expose the source commit used to publish them.
 */
export function oracleReleaseContractIssues({ manifest, lockText }) {
  const issues = [];
  let lock;
  try {
    if (typeof lockText !== 'string') throw new Error('missing lockfile');
    lock = parseOracleLock(lockText);
    if (lock?.lockfileVersion !== 2) {
      issues.push('oracle lockfileVersion must remain 2');
    }
  } catch {
    issues.push('oracle lockfile is missing or invalid');
  }
  if (manifest?.private !== true) issues.push('oracle package must remain private');
  if (lock && lock.workspaces?.['']?.name !== manifest?.name) {
    issues.push('oracle lockfile package name must match its manifest');
  }
  for (const [name, version] of Object.entries(ORACLE_PACKAGE_VERSIONS)) {
    if (manifest?.devDependencies?.[name] !== version) {
      issues.push(`${name} manifest pin must be ${version}`);
    }
    if (lock) {
      if (lock.workspaces?.['']?.devDependencies?.[name] !== version) {
        issues.push(`${name} lockfile manifest pin must be ${version}`);
      }
      const entry = lock.packages?.[name];
      if (!Array.isArray(entry) || entry[0] !== `${name}@${version}`) {
        issues.push(`${name}@${version} is missing from the oracle lockfile`);
      } else if (entry[3] !== packageIntegrities[name]) {
        issues.push(`${name}@${version} lockfile integrity differs from the reviewed release`);
      }
    }
  }
  if (manifest?.packageManager !== 'bun@1.4.4') {
    issues.push('oracle packageManager must remain bun@1.4.4');
  }
  return issues;
}

export function assertOracleReleaseContract(input) {
  const issues = oracleReleaseContractIssues(input);
  if (issues.length > 0) {
    throw new Error(
      `StyleX ${STYLEX_RELEASE_TAG} oracle release contract failed:\n${issues
        .map((issue) => `- ${issue}`)
        .join(
          '\n',
        )}\nRestore the reviewed oracle pins and lockfile, then run vp -C tools/stylex-oracle install --frozen-lockfile.\nRecorded release commit: ${STYLEX_RELEASE_COMMIT}`,
    );
  }
  return {
    stylexVersion: STYLEX_RELEASE_VERSION,
    releaseTag: STYLEX_RELEASE_TAG,
    releaseCommit: STYLEX_RELEASE_COMMIT,
    babelVersion: BABEL_VERSION,
  };
}
