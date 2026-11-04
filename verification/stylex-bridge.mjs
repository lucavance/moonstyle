const IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;
const PROPERTY = /^[A-Za-z_-][A-Za-z0-9_-]*$/;
const SAFE_SUFFIX = /^[A-Za-z0-9%._ +\-/]*$/;

function fail(message) {
  throw new Error(`Invalid style manifest: ${message}`);
}

export function validateManifest(manifest) {
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    fail('root must be an object');
  }
  if (manifest.schemaVersion !== 1) {
    fail('schemaVersion must be 1');
  }
  if (!IDENTIFIER.test(manifest.exportName ?? '')) {
    fail('exportName must be a MoonBit and JavaScript identifier');
  }
  if (!Array.isArray(manifest.namespaces) || manifest.namespaces.length === 0) {
    fail('namespaces must be a non-empty array');
  }

  const names = new Set();
  for (const namespace of manifest.namespaces) {
    if (!namespace || typeof namespace !== 'object') {
      fail('each namespace must be an object');
    }
    if (!IDENTIFIER.test(namespace.name ?? '')) {
      fail(`namespace name ${JSON.stringify(namespace.name)} is invalid`);
    }
    if (names.has(namespace.name)) {
      fail(`duplicate namespace ${namespace.name}`);
    }
    names.add(namespace.name);
    if (!Array.isArray(namespace.declarations) || namespace.declarations.length === 0) {
      fail(`namespace ${namespace.name} must contain declarations`);
    }

    let dynamicCount = 0;
    const properties = new Set();
    for (const declaration of namespace.declarations) {
      if (!PROPERTY.test(declaration?.property ?? '')) {
        fail(`invalid property in namespace ${namespace.name}`);
      }
      if (properties.has(declaration.property)) {
        fail(`duplicate property ${declaration.property} in namespace ${namespace.name}`);
      }
      properties.add(declaration.property);
      const value = declaration.value;
      if (!value || typeof value !== 'object') {
        fail(`property ${declaration.property} must have a value object`);
      }
      if (value.kind === 'static') {
        if (typeof value.value !== 'string') {
          fail(`static property ${declaration.property} must contain a string`);
        }
      } else if (value.kind === 'conditional') {
        if (typeof value.default !== 'string' || !Array.isArray(value.branches)) {
          fail(`conditional property ${declaration.property} is malformed`);
        }
        for (const branch of value.branches) {
          const kind = branch?.condition?.kind;
          const condition = branch?.condition?.value;
          if (!['pseudo', 'at-rule'].includes(kind) || typeof condition !== 'string') {
            fail(`conditional branch for ${declaration.property} is malformed`);
          }
          if (kind === 'pseudo' && !condition.startsWith(':')) {
            fail(`pseudo condition ${condition} must start with ':'`);
          }
          if (kind === 'at-rule' && !condition.startsWith('@')) {
            fail(`at-rule condition ${condition} must start with '@'`);
          }
          if (typeof branch.value !== 'string') {
            fail(`conditional branch for ${declaration.property} must contain a string`);
          }
        }
      } else if (value.kind === 'dynamic') {
        dynamicCount += 1;
        if (typeof value.suffix !== 'string' || !SAFE_SUFFIX.test(value.suffix)) {
          fail(`dynamic suffix for ${declaration.property} is unsafe`);
        }
      } else {
        fail(`unsupported value kind ${JSON.stringify(value.kind)}`);
      }
    }
    if (dynamicCount > 1) {
      fail(`namespace ${namespace.name} has more than one dynamic property`);
    }
  }
  return manifest;
}

function renderConditional(value) {
  const fields = [
    `${JSON.stringify('default')}: ${JSON.stringify(value.default)}`,
    ...value.branches.map(
      (branch) => `${JSON.stringify(branch.condition.value)}: ${JSON.stringify(branch.value)}`,
    ),
  ];
  return `{ ${fields.join(', ')} }`;
}

function renderDeclaration(declaration) {
  const key = JSON.stringify(declaration.property);
  const value = declaration.value;
  if (value.kind === 'static') {
    return `${key}: ${JSON.stringify(value.value)}`;
  }
  if (value.kind === 'conditional') {
    return `${key}: ${renderConditional(value)}`;
  }
  return `${key}: \`${'${value}'}${value.suffix}\``;
}

export function renderStylexModule(input) {
  const manifest = validateManifest(input);
  const namespaces = manifest.namespaces.map((namespace) => {
    const body = namespace.declarations.map(renderDeclaration).join(',\n      ');
    const isDynamic = namespace.declarations.some((decl) => decl.value.kind === 'dynamic');
    const value = isDynamic ? `value => ({\n      ${body}\n    })` : `{\n      ${body}\n    }`;
    return `    ${JSON.stringify(namespace.name)}: ${value}`;
  });
  return [
    "import * as stylex from '@stylexjs/stylex';",
    '',
    `export const ${manifest.exportName} = stylex.create({`,
    namespaces.join(',\n'),
    '});',
    '',
  ].join('\n');
}
