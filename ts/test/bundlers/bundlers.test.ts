// The workload (test/helpers/workload.ts) bundled from dist/ by each common bundler, run with and without BigInt:
// both must match src/, so no bundler may drop either Long implementation. Builds dist/ first (tsc -b).

import { beforeAll, describe, expect, it } from "vitest";
import { execFile, execFileSync } from "node:child_process";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { literalWorkload, runWorkload, workloadSource } from "../helpers/workload.ts";
import * as core from "../../src/noda-js/index.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { esES } from "../../src/noda-js/Cultures/index.generated.ts";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
// Under ts/, so the bundlers find ts/node_modules.
const dir = path.join(root, "test-results/bundlers");
const entry = path.join(dir, "app.mjs");
const noBigInt = path.join(dir, "no-bigint.mjs");

const bun = (() => {
  try {
    execFileSync("bun", ["--version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
})();

const run = promisify(execFile);

function expected(): Record<string, string> {
  const results = runWorkload({ ...core, tzdb, esES });
  delete results.long;
  return results;
}

/** Runs a script in Node (with BigInt deleted first, or not) and returns the workload's results. */
async function runInNode(file: string, withoutBigInt: boolean): Promise<Record<string, string>> {
  const args = withoutBigInt ? ["--import", pathToFileURL(noBigInt).href, file] : [file];
  const { stdout } = await run(process.execPath, args, { maxBuffer: 16 * 1024 * 1024 });
  return JSON.parse(stdout.trim().split("\n").pop()!) as Record<string, string>;
}

async function checkOutput(file: string, bundled = true): Promise<void> {
  if (bundled) {
    const code = await readFile(file, "utf8");
    // Both implementations are in the bundle: long.js (its Long's marker property) and the BigInt one.
    expect(code, "long.js").toContain("__isLong__");
    expect(code, "the BigInt-backed Long").toContain("asIntN");
  }
  for (const withoutBigInt of [false, true]) {
    const results = await runInNode(file, withoutBigInt);
    expect(results.long, `the 64-bit integer noda-js picked${withoutBigInt ? " without BigInt" : ""}`).toBe(withoutBigInt ? "long.js" : "bigint");
    const { long: _, ...rest } = results;
    expect(rest).toEqual(expected());
    for (const [name, value] of Object.entries(literalWorkload)) {
      expect(results[name], name).toBe(value);
    }
  }
}

beforeAll(async () => {
  await run(process.execPath, [createRequire(import.meta.url).resolve("typescript/bin/tsc"), "-b", path.join(root, "src/noda-js")]);
  await rm(dir, { recursive: true, force: true });
  await mkdir(dir, { recursive: true });
  await writeFile(entry, `import * as core from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import { esES } from "noda-js/cultures";
const run = (${workloadSource});
console.log(JSON.stringify(run(Object.assign({}, core, { tzdb: tzdb, esES: esES }))));
`);
  await writeFile(noBigInt, "delete globalThis.BigInt;\n");
}, 600_000);

const bundlerTimeout = 300_000;

const parcelInstalled = await import("@parcel/core").then(() => true, () => false);

describe("bundlers (the built package through its exports)", () => {
  it("Node itself (no bundler)", async () => {
    await checkOutput(entry, false);
  }, bundlerTimeout);

  it("esbuild", async () => {
    const { build } = await import("esbuild");
    const outfile = path.join(dir, "esbuild/app.mjs");
    await build({ entryPoints: [entry], outfile, bundle: true, format: "esm", platform: "neutral", target: "es2015", minify: true, logLevel: "silent" });
    await checkOutput(outfile);
  }, bundlerTimeout);

  it("Rollup (with @rollup/plugin-node-resolve)", async () => {
    const { rollup } = await import("rollup");
    const { nodeResolve } = await import("@rollup/plugin-node-resolve");
    const file = path.join(dir, "rollup/app.mjs");
    // Import cycles through internal.ts are by design.
    const bundle = await rollup({ input: entry, plugins: [nodeResolve()], onwarn: () => {} });
    await bundle.write({ file, format: "es" });
    await bundle.close();
    await checkOutput(file);
  }, bundlerTimeout);

  it("webpack 5", async () => {
    const { default: webpack } = await import("webpack");
    const outDir = path.join(dir, "webpack");
    const stats = await new Promise<import("webpack").Stats>((resolve, reject) => {
      webpack({
        mode: "production",
        context: dir,
        entry,
        target: ["web", "es2015"],
        devtool: false,
        performance: false,
        output: { path: outDir, filename: "app.cjs" },
      }, (error, result) => (error || !result ? reject(error ?? new Error("no stats")) : resolve(result)));
    });
    expect(stats.hasErrors(), stats.toString("errors-only")).toBe(false);
    await checkOutput(path.join(outDir, "app.cjs"));
  }, bundlerTimeout);

  it("Vite (vite build)", async () => {
    const { build } = await import("vite");
    const outDir = path.join(dir, "vite");
    await build({
      configFile: false,
      root: dir,
      logLevel: "silent",
      build: { outDir, emptyOutDir: true, minify: true, lib: { entry, formats: ["es"], fileName: () => "app.mjs" } },
    });
    await checkOutput(path.join(outDir, "app.mjs"));
  }, bundlerTimeout);

  // Optional: no native build on some platforms (Windows ARM64).
  it.skipIf(!parcelInstalled)("Parcel 2", async () => {
    const { Parcel } = await import("@parcel/core");
    // A project of its own: Parcel needs packageExports turned on in package.json.
    const project = path.join(dir, "parcel");
    await mkdir(project, { recursive: true });
    await writeFile(path.join(project, "package.json"), JSON.stringify({
      name: "parcel-consumer",
      private: true,
      "@parcel/resolver-default": { packageExports: true },
    }));
    await writeFile(path.join(project, "package-lock.json"), JSON.stringify({ name: "parcel-consumer", lockfileVersion: 3, packages: {} }));
    const projectEntry = path.join(project, "app.mjs");
    await writeFile(projectEntry, await readFile(entry, "utf8"));
    const distDir = path.join(project, "dist");
    const bundler = new Parcel({
      entries: projectEntry,
      defaultConfig: "@parcel/config-default",
      mode: "production",
      shouldDisableCache: true,
      cacheDir: path.join(project, ".parcel-cache"),
      logLevel: "error",
      targets: {
        app: { distDir, outputFormat: "esmodule", context: "browser", isLibrary: false, optimize: true, sourceMap: false, engines: { browsers: "Chrome >= 80" } },
      },
    });
    const { bundleGraph } = await bundler.run();
    const output = bundleGraph.getBundles().find((b) => b.type === "js")!.filePath;
    await checkOutput(output.endsWith(".mjs") ? output : await asModule(output));
  }, bundlerTimeout);

  it.skipIf(!bun)("Bun (bun build)", async () => {
    const outfile = path.join(dir, "bun/app.mjs");
    await run("bun", ["build", entry, "--outfile", outfile, "--target", "browser", "--minify"]);
    await checkOutput(outfile);
  }, bundlerTimeout);
});

/** A copy of an ES module bundle named .mjs, so Node runs it as one. */
async function asModule(file: string): Promise<string> {
  const copy = `${file}.mjs`;
  await writeFile(copy, await readFile(file));
  return copy;
}
