import { execFile } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { promisify } from 'node:util';

const execute = promisify(execFile);
const virtual = 'virtual:moonstyle.css';
const resolved = `\0${virtual}`;

/** Optional host adapter. Configuration, validation and extraction belong to the native CLI. */
export default function moonStyle({ executable = process.env.MOONSTYLE_BIN ?? 'moonstyle' } = {}) {
  let root;
  let server;
  let report;
  let queue = Promise.resolve();
  let cssFile;
  let generated = [];

  const generate = () => {
    const next = queue.then(async () => {
      let stdout;
      try {
        ({ stdout } = await execute(executable, ['generate', '--root', root, '--json'], {
          maxBuffer: 16 * 1024 * 1024,
        }));
      } catch (error) {
        stdout = error.stdout;
        if (!stdout) throw error;
      }
      const outcome = JSON.parse(stdout);
      if (!outcome.passed) {
        const message = outcome.diagnostics
          .map((item) => `${item.code}: ${item.message}`)
          .join('\n');
        throw new Error(message);
      }
      report = outcome;
      const inputs = report.extraction.resolved;
      cssFile = path.resolve(root, inputs.outputs.css);
      generated = Object.values(inputs.outputs).map((file) => path.resolve(root, file));
      server?.watcher.add(inputs.workspaceRoots ?? [root]);
      return outcome;
    });
    queue = next.catch(() => {});
    return next;
  };

  return {
    name: 'moonstyle',
    enforce: 'pre',
    configResolved(config) {
      root = config.root;
    },
    configureServer(value) {
      server = value;
    },
    async buildStart() {
      try {
        await generate();
      } catch (error) {
        this.error(error);
      }
      this.addWatchFile(path.join(root, 'style.config.json'));
      for (const directory of report.extraction.resolved.workspaceRoots ?? [root])
        this.addWatchFile(directory);
    },
    resolveId(id) {
      return id === virtual ? resolved : null;
    },
    load(id) {
      if (id !== resolved) return null;
      this.addWatchFile(cssFile);
      return fs.readFileSync(cssFile, 'utf8');
    },
    async handleHotUpdate(context) {
      const file = context.file;
      if (
        generated.includes(file) ||
        /[/\\](?:_build|node_modules|\.git|dist|\.mooncakes)[/\\]/.test(file)
      )
        return;
      if (
        !/\.(?:mbt|mbti|bundle\.json)$/.test(file) &&
        !/[/\\](?:moon\.(?:mod|pkg|work)(?:\.json)?|style\.config\.json|\.moonstyle\.json)$/.test(
          file,
        )
      )
        return;
      try {
        await generate();
        const module = server.moduleGraph.getModuleById(resolved);
        if (module) server.moduleGraph.invalidateModule(module);
        server.ws.send({ type: 'full-reload' });
      } catch (error) {
        server.ws.send({ type: 'error', err: { message: error.message, plugin: 'moonstyle' } });
      }
      return [];
    },
  };
}
