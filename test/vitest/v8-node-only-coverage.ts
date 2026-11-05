// Coverage for `npm run test:ci`: Vitest's v8 provider (@vitest/coverage-v8), measured in the node project only.
//
// Vitest refuses `coverage.provider: "v8"` when Firefox or WebKit projects are in the run (v8 coverage in a browser
// needs Chromium's DevTools protocol), and coverage options are global, not per project. As a custom provider this
// module is loaded on Node (where it is the v8 provider) and in each browser tester page, where it's inert: Vitest's
// start/take/stopCoverage hooks are optional, and getProvider is only called on Node. Browsers run the same src/, so
// Node's coverage is the coverage.

import type { CoverageProviderModule } from "vitest/node";

const v8Module = "@vitest/coverage-v8";

// On Node: the v8 provider, resolved to its file with Node's resolver (Vitest's module runner resolves a bare
// specifier imported this way against the root, not node_modules). The node: modules are imported here, not at the
// top, so the browser pages never load them.
async function loadV8Provider(): Promise<CoverageProviderModule> {
  const { createRequire } = (await import(/* @vite-ignore */ "node:module" as string)) as typeof import("node:module");
  const { pathToFileURL } = (await import(/* @vite-ignore */ "node:url" as string)) as typeof import("node:url");
  const file = createRequire(import.meta.url).resolve(v8Module);
  return ((await import(/* @vite-ignore */ pathToFileURL(file).href)) as { default: CoverageProviderModule }).default;
}

const provider: CoverageProviderModule =
  typeof window === "undefined"
    ? await loadV8Provider()
    : {
        getProvider() {
          throw new Error("The v8 coverage provider runs on Node only.");
        },
      };

export default provider;
