import { transformSync } from '@babel/core';
import stylexPlugin from '@stylexjs/babel-plugin';
import { renderStylexModule } from '../stylex-bridge.mjs';

export function compileStylexSource(source, pluginOptions = {}) {
  const result = transformSync(source, {
    filename: '/virtual/moonstyle/styles.stylex.mjs',
    babelrc: false,
    configFile: false,
    sourceMaps: false,
    plugins: [[stylexPlugin, { runtimeInjection: false, ...pluginOptions }]],
  });
  const rules = result?.metadata?.stylex ?? [];
  const css = stylexPlugin.processStylexRules(rules, { useLayers: false });
  return { code: result?.code ?? '', rules, css };
}

export function compileManifest(manifest) {
  const source = renderStylexModule(manifest);
  const compiled = compileStylexSource(source);
  return { source, ...compiled };
}
