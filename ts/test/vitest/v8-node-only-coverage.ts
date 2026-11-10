// The v8 coverage provider on Node, inert in browser pages (Vitest refuses "v8" with Firefox or WebKit projects).
// No top-level await: concurrent imports could see this module without its default export.

import type { CoverageProvider, CoverageProviderModule } from "vitest/node";

const v8Module = "@vitest/coverage-v8";

// Not imported at the top, so browser pages never load them.
async function nodeModules() {
  return {
    module: (await import(/* @vite-ignore */ "node:module" as string)) as typeof import("node:module"),
    url: (await import(/* @vite-ignore */ "node:url" as string)) as typeof import("node:url"),
  };
}

// Resolved with Node's resolver (Vitest's would resolve against the root); one shared instance holds the session.
async function v8(): Promise<CoverageProviderModule> {
  const { module, url } = await nodeModules();
  const file = module.createRequire(import.meta.url).resolve(v8Module);
  return ((await import(/* @vite-ignore */ url.pathToFileURL(file).href)) as { default: CoverageProviderModule }).default;
}

const nodeProvider: CoverageProviderModule = {
  async getProvider(): Promise<CoverageProvider> {
    return (await v8()).getProvider();
  },
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
