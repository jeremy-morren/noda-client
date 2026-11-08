// Coverage for `npm run test:ci`: Vitest's v8 provider (@vitest/coverage-v8), measured in the node project only.
//
// Vitest refuses `coverage.provider: "v8"` when Firefox or WebKit projects are in the run (v8 coverage in a browser
// needs Chromium's DevTools protocol), and coverage options are global, not per project. As a custom provider this
// module is loaded on Node (where it is the v8 provider) and in each browser tester page, where it's inert: Vitest's
// start/take/stopCoverage hooks are optional, and getProvider is only called on Node. Browsers run the same src/, so
// Node's coverage is the coverage.
//
// CI runs the node project on Linux, Windows and macOS; each job's coverage/coverage-final.json is merged by
// test/vitest/merge-coverage.ts (scripts/merge-test-reports.ps1), not by Vitest.
//
// No top-level await: Vitest imports this module several times, sometimes concurrently, and a concurrent import of a
// module still awaiting can see it without its default export. So the v8 module is loaded on first use.

import type { CoverageProvider, CoverageProviderModule } from "vitest/node";

const v8Module = "@vitest/coverage-v8";

// The node: modules are imported here, not at the top, so the browser pages never load them.
async function nodeModules() {
  return {
    module: (await import(/* @vite-ignore */ "node:module" as string)) as typeof import("node:module"),
    url: (await import(/* @vite-ignore */ "node:url" as string)) as typeof import("node:url"),
  };
}

// The v8 provider module, resolved to its file with Node's resolver (Vitest's module runner resolves a bare specifier
// imported this way against the root, not node_modules). Node caches it, so every import of this module shares one:
// it keeps its inspector session on itself between startCoverage and takeCoverage.
async function v8(): Promise<CoverageProviderModule> {
  const { module, url } = await nodeModules();
  const file = module.createRequire(import.meta.url).resolve(v8Module);
  return ((await import(/* @vite-ignore */ url.pathToFileURL(file).href)) as { default: CoverageProviderModule }).default;
}

const nodeProvider: CoverageProviderModule = {
  async getProvider(): Promise<CoverageProvider> {
    return (await v8()).getProvider();
  },
  // In each test worker. (Called on the v8 module itself, which holds the session.)
  async startCoverage(options) {
    return (await v8()).startCoverage?.(options);
  },
  async takeCoverage(options) {
    return (await v8()).takeCoverage?.(options);
  },
  async stopCoverage(options) {
    return (await v8()).stopCoverage?.(options);
  },
};

const provider: CoverageProviderModule =
  typeof window === "undefined"
    ? nodeProvider
    : {
        getProvider() {
          throw new Error("The v8 coverage provider runs on Node only.");
        },
      };

export default provider;
