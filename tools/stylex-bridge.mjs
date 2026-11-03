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

function moonString(value) {
  return JSON.stringify(String(value));
}

function renderEntries(entries, indent = '  ') {
  if (entries.length === 0) return '[]';
  return `[\n${entries.map(([key, value]) => `${indent}  (${moonString(key)}, ${moonString(value)}),`).join('\n')}\n${indent}]`;
}

export function extractCompiledStyles(manifest, moduleExports, sampleValue = 37) {
  const exported = moduleExports[manifest.exportName];
  if (!exported || typeof exported !== 'object') {
    throw new Error(`Compiled module does not export ${manifest.exportName}`);
  }
  return manifest.namespaces.map((namespace) => {
    const dynamicDeclaration = namespace.declarations.find(
      (declaration) => declaration.value.kind === 'dynamic',
    );
    const compiledValue = exported[namespace.name];
    let styleObject = compiledValue;
    let inlineObject = {};
    if (dynamicDeclaration) {
      if (typeof compiledValue !== 'function') {
        throw new Error(`Compiled dynamic namespace ${namespace.name} is not a function`);
      }
      const evaluated = compiledValue(sampleValue);
      if (!Array.isArray(evaluated) || evaluated.length !== 2) {
        throw new Error(`Compiled dynamic namespace ${namespace.name} has an unexpected shape`);
      }
      [styleObject, inlineObject] = evaluated;
    }
    const entries = Object.entries(styleObject).filter(([key]) => !key.startsWith('$$'));
    const inlineVars = Object.entries(inlineObject).filter(([, value]) => value != null);
    return { namespace, dynamicDeclaration, entries, inlineVars };
  });
}

export function renderMoonbitModule(manifest, compiledStyles) {
  const output = ['// Generated by tools/build-styles.mjs. Do not edit.', ''];
  for (const style of compiledStyles) {
    const name = style.namespace.name;
    if (!style.dynamicDeclaration) {
      output.push('///|');
      output.push(`pub let ${name} : @css.CompiledStyle = @css.compiled(`);
      output.push(`${renderEntries(style.entries)}`);
      output.push(')');
      output.push('');
      continue;
    }
    if (style.inlineVars.length !== 1) {
      throw new Error(`Dynamic namespace ${name} must compile to exactly one inline variable`);
    }
    const variableName = style.inlineVars[0][0];
    const suffix = style.dynamicDeclaration.value.suffix;
    output.push('///|');
    output.push(`pub fn ${name}(value : Int) -> @css.CompiledStyle {`);
    output.push('  @css.compiled(');
    output.push(`${renderEntries(style.entries, '  ')},`);
    output.push(
      `    inline_vars=[(${moonString(variableName)}, value.to_string() + ${moonString(suffix)})],`,
    );
    output.push('  )');
    output.push('}');
    output.push('');
  }
  return `${output.join('\n').trimEnd()}\n`;
}

export function renderCss(css) {
  return `/* Generated by tools/build-styles.mjs. Do not edit. */\n${css.trim()}\n`;
}
