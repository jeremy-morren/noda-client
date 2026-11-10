// noda-js: new code. Builds the single-file ES module (noda-js.js, minified ES2015); run by `npm run build:module`.
import { build, type BuildOptions } from "esbuild";
import { mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/** The esbuild options for the module, writing noda-js.js (and its map) to outdir. */
export function moduleBuildOptions(outdir: string): BuildOptions {
  return {
    absWorkingDir: root,
    entryPoints: [{ in: "standalone/noda-js.ts", out: "noda-js" }],
    outdir,
    bundle: true,
    format: "esm",
    platform: "neutral",
    target: "es2015",
    minify: true,
    sourcemap: "linked",
    // Licence comments (e.g. long.js's) go at the end of the file.
    legalComments: "eof",
    logLevel: "warning",
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const outdir = path.join(root, "artifacts", "module");
  await rm(outdir, { recursive: true, force: true });
  await mkdir(outdir, { recursive: true });
  await build(moduleBuildOptions(outdir));
  console.log(`Wrote ${path.relative(root, outdir).split(path.sep).join("/")}/noda-js.js and noda-js.js.map`);
}
