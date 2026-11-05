// noda-js-zod tree-shaking: an app that uses one schema shouldn't bundle the others. Each schema is a
// /* @__PURE__ */ call in src/noda-js-zod/schemas.ts, and index.ts default-exports that module's namespace (NodaZ).
//
// Node only (esbuild, rollup, node:fs). vitest.config.ts's `nodeOnly` list is for whole files; until this file is
// added to it, the suite skips itself outside Node and loads its Node-only modules dynamically, so the browser
// projects never import them.

import { describe, expect, it } from "vitest";

const isNode = typeof window === "undefined";

/** Strings only the given schema's code contains (they aren't in the core, nor in the other schemas). */
const markers = {
  // The error-message helper every schema uses.
  any: "string in the format",
  Period: "P{years}Y",
  Offset: "+HH:mm or +HH",
  Interval: "an Interval",
  DateInterval: "a DateInterval",
  DateTimeZone: "provider's Ids",
};

const otherSchemas = ["Period", "Offset", "Interval", "DateInterval", "DateTimeZone"] as const;

// Module specifiers in variables, so that Vite doesn't try to resolve them for the browser projects.
const esbuildModule = "esbuild";
const rollupModule = "rollup";
const fsModule = "node:fs";
const pathModule = "node:path";
const urlModule = "node:url";

async function setup() {
  const esbuild = (await import(/* @vite-ignore */ esbuildModule)) as typeof import("esbuild");
  const { rollup } = (await import(/* @vite-ignore */ rollupModule)) as typeof import("rollup");
  const { readFileSync } = (await import(/* @vite-ignore */ fsModule)) as typeof import("node:fs");
  const path = (await import(/* @vite-ignore */ pathModule)) as typeof import("node:path");
  const { fileURLToPath } = (await import(/* @vite-ignore */ urlModule)) as typeof import("node:url");

  const root = fileURLToPath(new URL("../../", import.meta.url));
  const zodPackage = path.join(root, "src/noda-js-zod/index.ts");
  const zodSchemas = path.join(root, "src/noda-js-zod/schemas.ts");
  const nodaJs = path.join(root, "src/noda-js/index.ts");

  /** An installed package's ESM entry point (its `exports["."].import`). */
  function resolvePackage(name: string): string {
    const directory = path.join(root, "node_modules", name);
    const manifest = JSON.parse(readFileSync(path.join(directory, "package.json"), "utf8")) as {
      exports: { ".": { import: string | { default: string } } };
    };
    const target = manifest.exports["."].import;
    return path.join(directory, typeof target === "string" ? target : target.default);
  }

  /** Bundles with esbuild (production settings), "noda-js" being the core's sources. */
  async function esbuildBundle(source: string): Promise<string> {
    const result = await esbuild.build({
      stdin: { contents: source, resolveDir: root, loader: "ts", sourcefile: "app.ts" },
      alias: { "noda-js": nodaJs },
      bundle: true,
      write: false,
      minify: true,
      treeShaking: true,
      format: "esm",
      platform: "neutral",
      target: "es2015",
      logLevel: "silent",
    });
    return result.outputFiles[0]!.text;
  }

  /** Bundles with rollup (as Vite's production build does), then minifies to drop comments. */
  async function rollupBundle(source: string): Promise<string> {
    const entry = "\0app.ts";
    const bundle = await rollup({
      input: entry,
      onwarn: () => {},
      plugins: [
        {
          name: "noda-js-zod-test",
          resolveId(id) {
            if (id === entry) {
              return id;
            }
            if (id === "noda-js") {
              return nodaJs;
            }
            if (id === "zod" || id === "long") {
              return resolvePackage(id);
            }
            return null;
          },
          load(id) {
            return id === entry ? source : null;
          },
          async transform(code, id) {
            if (id === entry || id.endsWith(".ts")) {
              return (await esbuild.transform(code, { loader: "ts", target: "es2022" })).code;
            }
            return null;
          },
        },
      ],
    });
    const { output } = await bundle.generate({ format: "es" });
    await bundle.close();
    return (await esbuild.transform(output[0].code, { minify: true, target: "es2022" })).code;
  }

  return { esbuildBundle, rollupBundle, zodPackage, zodSchemas };
}

const imported = (code: string, schema: keyof typeof markers) => code.includes(markers[schema]);

describe.runIf(isNode)("noda-js-zod tree shaking", () => {
  const ready = isNode ? setup() : undefined;

  it("rollup: NodaZ (the default export) used for Instant only: no other schema", async () => {
    const { rollupBundle, zodPackage } = await ready!;
    const code = await rollupBundle(`
      import NodaZ from ${JSON.stringify(zodPackage)};
      console.log(NodaZ.Instant.parse("2024-01-31T12:00:00Z"));
    `);
    expect(imported(code, "any")).toBe(true);
    for (const schema of otherSchemas) {
      expect(imported(code, schema), schema).toBe(false);
    }
  }, 120000);

  it("rollup: the whole NodaZ namespace keeps every schema (the checks can tell the difference)", async () => {
    const { rollupBundle, zodPackage } = await ready!;
    const code = await rollupBundle(`import NodaZ from ${JSON.stringify(zodPackage)}; console.log(NodaZ);`);
    for (const schema of otherSchemas) {
      expect(imported(code, schema), schema).toBe(true);
    }
  }, 120000);

  it("esbuild: the schemas module, used for Instant only: no other schema", async () => {
    const { esbuildBundle, zodSchemas } = await ready!;
    const code = await esbuildBundle(`
      import * as NodaZ from ${JSON.stringify(zodSchemas)};
      console.log(NodaZ.Instant.parse("2024-01-31T12:00:00Z"));
    `);
    expect(imported(code, "any")).toBe(true);
    for (const schema of otherSchemas) {
      expect(imported(code, schema), schema).toBe(false);
    }
  }, 60000);

  // esbuild (0.28) builds the full namespace object when a module re-exports a namespace (`export default NodaZ`,
  // `export { NodaZ }` or `export * as NodaZ`), so through the package entry point it keeps every schema (about
  // 3 kB minified, on top of the core and zod). If esbuild learns to tree-shake this, this test fails: drop `.fails`.
  it.fails("esbuild: NodaZ (the default export) used for Instant only: no other schema", async () => {
    const { esbuildBundle, zodPackage } = await ready!;
    const code = await esbuildBundle(`
      import NodaZ from ${JSON.stringify(zodPackage)};
      console.log(NodaZ.Instant.parse("2024-01-31T12:00:00Z"));
    `);
    for (const schema of otherSchemas) {
      expect(imported(code, schema), schema).toBe(false);
    }
  }, 60000);
});
