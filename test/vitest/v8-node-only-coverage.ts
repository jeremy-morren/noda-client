// Coverage for `npm run test:ci`: Vitest's v8 provider (@vitest/coverage-v8), measured in the node project only.
//
// Vitest refuses `coverage.provider: "v8"` when Firefox or WebKit projects are in the run (v8 coverage in a browser
// needs Chromium's DevTools protocol), and coverage options are global, not per project. As a custom provider this
// module is loaded on Node (where it is the v8 provider) and in each browser tester page, where it's inert: Vitest's
// start/take/stopCoverage hooks are optional, and getProvider is only called on Node. Browsers run the same src/, so
// Node's coverage is the coverage.

import type { CoverageProviderModule } from "vitest/node";

const v8Module = "@vitest/coverage-v8";

const provider: CoverageProviderModule =
  typeof window === "undefined"
    ? (await import(/* @vite-ignore */ v8Module)).default
    : {
        getProvider() {
          throw new Error("The v8 coverage provider runs on Node only.");
        },
      };

export default provider;
